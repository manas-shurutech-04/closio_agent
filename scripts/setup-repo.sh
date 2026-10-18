#!/usr/bin/env bash
# Gets a registered repo ready to work on, on this Mac: the flow-setup-repo command (F6, D54).
# Run it from the closio-agent folder:  bash scripts/setup-repo.sh <action>
#
#   check-folder                      Is this session in the closio-agent folder? (strict rule, D42)
#   list                              Each repo's setup state on this Mac (only reads)
#   run <repo|all>                    Set up one repo, or every repo cloned on this Mac
#   run <repo|all> install            The same, but always reinstall the packages
#   run <repo|all> services           The same, but choose Homebrew or Docker again for Redis and RabbitMQ
#
# What a run does, per repo (D54): checks the clone; shows its branch (never switches branches, pulls,
# stashes or changes tracked files: the card phases do that); switches to the repo's own Node version
# (nvm install if missing, rule A13); checks the env file by name; installs packages when needed; finds
# or starts the local Redis / RabbitMQ (Homebrew or Docker); checks, without showing any value, whether
# the repo's .env points to them, with step-by-step help; runs the tests once; gives Claude Code access
# to the repo folder; saves the result in local/repos/<repo>.yaml.
# It never clones (D53), never needs the VPN, and never prints what's inside a .env file (rule A6).
# Every ❌ comes with the steps to fix it (rule A11).

set -u

AGENT_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
. "$AGENT_ROOT/config/project-settings.sh"
REPOS_DIR="${REPOS_DIR:-$AGENT_ROOT/config/repos}"
LOCAL_REPOS_DIR="${LOCAL_REPOS_DIR:-$AGENT_ROOT/local/repos}"
LOGS_DIR="${LOGS_DIR:-$AGENT_ROOT/local/logs}"
USER_SETTINGS_FILE="${USER_SETTINGS_FILE:-$AGENT_ROOT/local/user-settings.sh}"
CLAUDE_LOCAL_SETTINGS="${CLAUDE_LOCAL_SETTINGS:-$AGENT_ROOT/.claude/settings.local.json}"
LOCAL_SERVICES_FILE="${LOCAL_SERVICES_FILE:-$AGENT_ROOT/config/local-services.yml}"
NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
# The programs it uses can be replaced by test stand-ins (used only by the build tests).
BREW="${BREW_BIN:-brew}"
DOCKER="${DOCKER_BIN:-docker}"
OSASCRIPT="${OSASCRIPT_BIN:-/usr/bin/osascript}"
OPEN="${OPEN_BIN:-open}"
CMD="/flow-setup-repo"

LOCAL_REDIS_FROM=""; LOCAL_RABBITMQ_FROM=""; AI_TOOLS=""
[ -f "$USER_SETTINGS_FILE" ] && . "$USER_SETTINGS_FILE"

to_fix=0
to_look=0
ok() { echo "✅ $1"; }
look() {
  echo "⚠️ $1"
  [ -n "${2:-}" ] && echo "   Tip: $2"
  to_look=$((to_look + 1))
}
bad() {
  echo "❌ $1"
  echo "   Fix: $2"
  [ -n "${3:-}" ] && echo "        $3"
  to_fix=$((to_fix + 1))
}
info() { echo "   $1"; }

# ---------------------------------------------------------------- helpers

yaml_get() { # <file> <key>: value of a flat "key: value" line ("" if missing); a " # comment" is dropped
  [ -f "$1" ] || return 0
  grep -m1 -E "^$2:" "$1" | sed -E "s/^$2:[[:space:]]*//; s/[[:space:]]+#.*$//; s/[[:space:]]+$//"
}

yaml_set() { # <file> <key> <value>: replaces the line, or adds it at the end
  local file="$1" key="$2" value="$3"
  if grep -q -E "^$key:" "$file" 2>/dev/null; then
    grep -v -E "^$key:" "$file" > "$file.tmp"
    printf '%s: %s\n' "$key" "$value" >> "$file.tmp"
    mv "$file.tmp" "$file"
  else
    printf '%s: %s\n' "$key" "$value" >> "$file"
  fi
}

valid_repo_name() { printf '%s' "$1" | grep -q -E '^[a-z0-9][a-z0-9._-]*$'; }
shared_file() { echo "$REPOS_DIR/$1.yaml"; }
local_file() { echo "$LOCAL_REPOS_DIR/$1.yaml"; }
gitlab_path_of() { printf '%s' "$1" | sed -E 's#://[^/@]*@#://#; s#^[a-z]+://[^/]+/##; s#^[^@]+@[^:]+:##; s#\.git$##'; }
has_item() { case ", $1," in *", $2,"*) return 0 ;; *) return 1 ;; esac; } # <comma list> <item>

nvm_sh() {
  if [ -s "$NVM_DIR/nvm.sh" ]; then echo "$NVM_DIR/nvm.sh"
  elif [ -s /opt/homebrew/opt/nvm/nvm.sh ]; then echo /opt/homebrew/opt/nvm/nvm.sh
  elif [ -s /usr/local/opt/nvm/nvm.sh ]; then echo /usr/local/opt/nvm/nvm.sh
  fi
}

# 'docker info' can hang while Docker Desktop is starting or stuck, so it gets a 10-second limit.
docker_answers() { # 0 = Docker answers; 124 = no answer within 10 s
  local pid waited=0
  { "$DOCKER" info >/dev/null 2>&1 & pid=$!
    while kill -0 "$pid" 2>/dev/null; do
      if [ "$waited" -ge 10 ]; then kill -KILL "$pid"; wait "$pid"; return 124; fi
      sleep 1; waited=$((waited + 1))
    done
    wait "$pid"; } 2>/dev/null
}

port_answers() { nc -z -G 2 "$1" "$2" >/dev/null 2>&1; } # <host> <port>

redis_reply() { # <host> <port> <command>: first line of Redis's answer
  printf '%s\r\n' "$3" | nc -G 2 -w 2 "$1" "$2" 2>/dev/null | tr -d '\r'
}

# Runs a command string in the repo folder, on the repo's Node version, with a time limit.
# Output goes to the log. Returns the command's exit code, or 124 when the time limit was hit.
run_in_repo() { # <path> <node version or ""> <seconds> <log> <command>
  local path="$1" nv="$2" limit="$3" log="$4" command="$5" pid waited=0 rc
  printf '\n$ %s   (in %s, %s)\n' "$command" "$path" "$(date '+%Y-%m-%d %H:%M:%S')" >> "$log"
  /usr/bin/perl -MPOSIX -e 'POSIX::setsid(); exec @ARGV' -- /bin/bash -c '
    cd "$1" || exit 96
    if [ -n "$2" ]; then
      . "$3" >/dev/null 2>&1 || exit 97
      nvm use "$2" >/dev/null 2>&1 || exit 98
    fi
    eval "$4"' _ "$path" "$nv" "$(nvm_sh)" "$command" >> "$log" 2>&1 < /dev/null &
  pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$waited" -ge "$limit" ]; then
      { kill -TERM -- "-$pid"; sleep 2; kill -KILL -- "-$pid"; wait "$pid"; } 2>/dev/null
      echo "closio-agent: stopped after $limit seconds (time limit)" >> "$log"
      return 124
    fi
    sleep 1
    waited=$((waited + 1))
  done
  wait "$pid"
  rc=$?
  return "$rc"
}

# macOS dialog with up to 3 buttons. Prints the button clicked ("" if closed or no answer in 5 minutes).
ask_dialog() { # <message> <button>...
  local msg="$1" buttons="" b last=""
  shift
  for b in "$@"; do buttons="${buttons:+$buttons, }\"$b\""; last="$b"; done
  "$OSASCRIPT" -e "set r to (display dialog \"$msg\" with title \"closio-agent setup\" buttons {$buttons} default button \"$last\" giving up after 300)" \
    -e 'if gave up of r then return ""' -e 'return button returned of r' 2>/dev/null
}

# ---------------------------------------------------------------- local services (Redis, RabbitMQ)

DOCKER_STATE=""          # "", running, not-installed, not-running, started-by-us
DOCKER_USED=""           # set when a service uses its Docker copy in this run
DONE_SERVICES=""         # services already decided in this run (for "all")
FORGET_CHOICE=""         # "yes" with the 'services' option

service_label() { case "$1" in redis) echo "Redis" ;; rabbitmq) echo "RabbitMQ" ;; esac; }
service_port() { case "$1" in redis) echo "$LOCAL_REDIS_PORT" ;; rabbitmq) echo "$LOCAL_RABBITMQ_PORT" ;; esac; }
saved_choice() { case "$1" in redis) echo "$LOCAL_REDIS_FROM" ;; rabbitmq) echo "$LOCAL_RABBITMQ_FROM" ;; esac; }

# Saves the choice in local/user-settings.sh (LOCAL_REDIS_FROM / LOCAL_RABBITMQ_FROM), keeping everything else.
save_choice() { # <service> <homebrew|docker>
  local var
  case "$1" in redis) var="LOCAL_REDIS_FROM"; LOCAL_REDIS_FROM="$2" ;; rabbitmq) var="LOCAL_RABBITMQ_FROM"; LOCAL_RABBITMQ_FROM="$2" ;; esac
  mkdir -p "$(dirname "$USER_SETTINGS_FILE")"
  touch "$USER_SETTINGS_FILE"
  grep -v -E "^$var=" "$USER_SETTINGS_FILE" > "$USER_SETTINGS_FILE.tmp"
  printf '%s="%s"   # homebrew or docker; set by flow-setup-repo (D54)\n' "$var" "$2" >> "$USER_SETTINGS_FILE.tmp"
  mv "$USER_SETTINGS_FILE.tmp" "$USER_SETTINGS_FILE"
}

# Homebrew copy: "<version> <status>" (status: started, stopped, ...), or "" if not installed with Homebrew.
brew_copy() { # <service>
  command -v "$BREW" >/dev/null 2>&1 || return 0
  local version status
  version="$("$BREW" list --versions "$1" 2>/dev/null | awk '{print $2}')"
  [ -n "$version" ] || return 0
  status="$("$BREW" services list 2>/dev/null | awk -v s="$1" '$1==s {print $2}')"
  echo "$version ${status:-stopped}"
}

# Docker must be running to look for a Docker copy. If Docker Desktop is installed but not running,
# it's started so both copies can be checked (D54); it's quit again at the end if nothing used it.
docker_ready() {
  case "$DOCKER_STATE" in running|started-by-us) return 0 ;; not-installed|not-running) return 1 ;; esac
  if ! command -v "$DOCKER" >/dev/null 2>&1; then DOCKER_STATE="not-installed"; return 1; fi
  if docker_answers; then DOCKER_STATE="running"; return 0; fi
  info "Docker Desktop isn't running. Starting it to look for Docker copies (up to $DOCKER_START_TIMEOUT s)..."
  "$OPEN" -g -a Docker >/dev/null 2>&1
  local waited=0
  while [ "$waited" -lt "$DOCKER_START_TIMEOUT" ]; do
    if docker_answers; then DOCKER_STATE="started-by-us"; return 0; fi
    sleep 3
    waited=$((waited + 3))
  done
  DOCKER_STATE="not-running"
  look "Docker Desktop didn't start within $DOCKER_START_TIMEOUT seconds, so Docker copies couldn't be checked" \
    "Open Docker Desktop yourself, wait until it says it's running, then run $CMD $CURRENT_REPO again."
  return 1
}

# Docker copy: "<container> <state> <host port>" for a container made from the official image, or "".
docker_copy() { # <service>  (call docker_ready first, outside $( ), so its state is kept)
  case "$DOCKER_STATE" in running|started-by-us) ;; *) return 0 ;; esac
  local line name state port
  line="$("$DOCKER" ps -a --format '{{.Names}} {{.State}} {{.Image}}' 2>/dev/null |
    awk -v s="$1" '{ img=$3; sub(/^docker\.io\//, "", img); sub(/^library\//, "", img)
                     if (img == s || index(img, s ":") == 1 || index(img, s "@") == 1) print $1, $2 }' |
    sort -k2,2r | head -1)"   # a running one first
  [ -n "$line" ] || return 0
  name="${line%% *}"; state="${line#* }"
  port="$("$DOCKER" inspect --format "{{(index (index .HostConfig.PortBindings \"$(service_port "$1")/tcp\") 0).HostPort}}" "$name" 2>/dev/null)"
  echo "$name $state ${port:-$(service_port "$1")}"
}

wait_for_port() { # <port> <seconds>
  local waited=0
  while [ "$waited" -lt "$2" ]; do
    port_answers 127.0.0.1 "$1" && return 0
    sleep 1
    waited=$((waited + 1))
  done
  return 1
}

# Finds the local copy of one service and makes sure it's running (D54). Sets USED_FROM_<service>
# (homebrew|docker) and USED_PORT_<service>.
setup_service() { # <service>
  local s="$1" label brew docker choice="" brew_ver brew_status d_name d_state d_port port answer from_text
  label="$(service_label "$s")"
  case " $DONE_SERVICES " in *" $s "*) ok "Local $label: checked above"; return 0 ;; esac
  DONE_SERVICES="$DONE_SERVICES $s"

  # 1. Check both: Homebrew and Docker.
  docker_ready
  brew="$(brew_copy "$s")"
  docker="$(docker_copy "$s")"
  brew_ver="${brew%% *}"; brew_status="${brew#* }"
  d_name="$(echo "$docker" | awk '{print $1}')"; d_state="$(echo "$docker" | awk '{print $2}')"; d_port="$(echo "$docker" | awk '{print $3}')"

  # 2. Choose.
  if [ -n "$brew" ] && [ -n "$docker" ]; then
    choice="$(saved_choice "$s")"
    [ "$FORGET_CHOICE" = "yes" ] && choice=""
    if [ "$choice" != "homebrew" ] && [ "$choice" != "docker" ]; then
      answer="$(ask_dialog "You have two copies of $label: Homebrew ($label $brew_ver) and Docker (container $d_name). Which one should closio-agent use? The other one is stopped if it's running, because both use the same port." "Not now" "Homebrew" "Docker")"
      case "$answer" in
        Homebrew) choice="homebrew" ;;
        Docker) choice="docker" ;;
        *) look "$label: you have a Homebrew and a Docker copy, and no choice was made" "Run $CMD $CURRENT_REPO services to choose."; return 1 ;;
      esac
      save_choice "$s" "$choice"
      info "Your choice for $label is saved ($choice). To change it: $CMD $CURRENT_REPO services"
    fi
  elif [ -n "$brew" ]; then
    choice="homebrew"
  elif [ -n "$docker" ]; then
    choice="docker"
  else
    # 3. None: suggest one; start it only after the user's yes.
    if [ "$DOCKER_STATE" = "running" ] || [ "$DOCKER_STATE" = "started-by-us" ]; then
      answer="$(ask_dialog "No local $label was found (not in Homebrew, not in Docker). closio-agent suggests Docker, from its shared file config/local-services.yml, so everyone has the same version. Start it now?" "Not now" "Start with Docker")"
      if [ "$answer" != "Start with Docker" ]; then
        look "No local $label (nothing was started)" "Run $CMD $CURRENT_REPO again and choose 'Start with Docker', or install it with Homebrew: brew install $s && brew services start $s"
        return 1
      fi
      if ! "$DOCKER" compose -f "$LOCAL_SERVICES_FILE" up -d "$s" >> "$LOGS_DIR/local-services.log" 2>&1; then
        bad "Couldn't start $label with Docker" "See local/logs/local-services.log, then run $CMD $CURRENT_REPO again."
        return 1
      fi
      choice="docker"; d_name="closio-agent-$s"; d_state="running"; d_port="$(service_port "$s")"
      save_choice "$s" docker
      ok "$label started with Docker (container $d_name, from config/local-services.yml)"
    elif command -v "$BREW" >/dev/null 2>&1; then
      answer="$(ask_dialog "No local $label was found, and Docker isn't available. closio-agent suggests installing it with Homebrew (brew install $s). Install and start it now?" "Not now" "Install with Homebrew")"
      if [ "$answer" != "Install with Homebrew" ]; then
        look "No local $label (nothing was installed)" "Run $CMD $CURRENT_REPO again and choose 'Install with Homebrew', or install Docker Desktop (docker.com)."
        return 1
      fi
      info "Installing $label with Homebrew (brew install $s)..."
      if ! "$BREW" install "$s" >> "$LOGS_DIR/local-services.log" 2>&1; then
        bad "Couldn't install $label with Homebrew" "See local/logs/local-services.log, then run $CMD $CURRENT_REPO again."
        return 1
      fi
      choice="homebrew"; brew_ver="$("$BREW" list --versions "$s" 2>/dev/null | awk '{print $2}')"; brew_status="stopped"
      save_choice "$s" homebrew
    else
      bad "No local $label, and neither Docker nor Homebrew is installed" \
        "Install Docker Desktop (docker.com) or Homebrew (brew.sh), then run $CMD $CURRENT_REPO again."
      return 1
    fi
  fi

  # 4. Stop the other copy if it's running (both use the same port). No password needed (D54).
  if [ "$choice" = "homebrew" ] && [ "$d_state" = "running" ]; then
    "$DOCKER" stop "$d_name" >/dev/null 2>&1 && ok "Stopped the Docker copy of $label (container $d_name): you use the Homebrew one"
  elif [ "$choice" = "docker" ] && [ "$brew_status" = "started" ]; then
    "$BREW" services stop "$s" >/dev/null 2>&1 && ok "Stopped the Homebrew copy of $label: you use the Docker one"
  fi

  # 5. Start the chosen copy if it's stopped, and check it answers.
  if [ "$choice" = "homebrew" ]; then
    port="$(service_port "$s")"
    if [ "$brew_status" != "started" ]; then
      "$BREW" services start "$s" >> "$LOGS_DIR/local-services.log" 2>&1
      info "Started the Homebrew copy of $label (brew services start $s)"
    fi
    from_text="Homebrew $label $brew_ver"
  else
    port="${d_port:-$(service_port "$s")}"
    DOCKER_USED="yes"
    if [ "$d_state" != "running" ]; then
      "$DOCKER" start "$d_name" >> "$LOGS_DIR/local-services.log" 2>&1
      info "Started the Docker copy of $label (container $d_name)"
    fi
    from_text="Docker container $d_name"
  fi
  eval "USED_FROM_$s=\$choice; USED_PORT_$s=\$port"
  if wait_for_port "$port" "$SERVICE_START_TIMEOUT"; then
    ok "Local $label: using $from_text, answering on port $port"
  else
    bad "Local $label ($from_text) doesn't answer on port $port" \
      "See local/logs/local-services.log. For Homebrew: brew services restart $s. For Docker: open Docker Desktop and start the container. Then run $CMD $CURRENT_REPO again."
    return 1
  fi

  # BullMQ needs Redis 6.2+ with maxmemory-policy noeviction (BullMQ docs).
  if [ "$s" = "redis" ] && [ "${NEEDS_BULLMQ:-}" = "yes" ]; then
    case "$(redis_reply 127.0.0.1 "$port" "CONFIG GET maxmemory-policy" | tr '\n' ' ')" in
      *noeviction*) ok "Redis memory setting is right for BullMQ (noeviction)" ;;
      *NOAUTH*|'') look "Couldn't read Redis's memory setting (BullMQ needs 'noeviction')" "Check it with: redis-cli CONFIG GET maxmemory-policy" ;;
      *) look "Redis's memory setting isn't 'noeviction', which BullMQ needs" "Run: redis-cli CONFIG SET maxmemory-policy noeviction (and set it in the Redis config file to keep it)" ;;
    esac
  fi
  return 0
}

# ---------------------------------------------------------------- .env check (values are never printed)

# Value of KEY in an env file, read by this script only. Never printed.
env_value() { # <file> <key>
  grep -m1 -E "^[[:space:]]*(export[[:space:]]+)?$2=" "$1" 2>/dev/null |
    sed -E "s/^[[:space:]]*(export[[:space:]]+)?$2=//; s/[[:space:]]+#.*$//; s/^[\"']//; s/[\"'][[:space:]]*$//; s/[[:space:]]+$//"
}
env_has_key() { grep -q -E "^[[:space:]]*(export[[:space:]]+)?$2=" "$1" 2>/dev/null; } # <file> <key>
ENV_OPENED=""   # the env file already opened in the editor for this repo
open_env_once() { # <env file>: opens it in the user's text editor (once per repo); returns 0 if it's open
  [ -n "$ENV_OPENED" ] && return 0
  "$OPEN" -t "$1" >/dev/null 2>&1 && ENV_OPENED="yes"
}
how_to_open() { # <env file>
  if open_env_once "$1"; then echo "   1. It's open in your text editor now: $1"
  else echo "   1. Open it:  open -t \"$1\""; fi
}

env_names() { # <file>: the variable NAMES set in an env file (never the values)
  grep -E '^[[:space:]]*(export[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*=' "$1" 2>/dev/null |
    sed -E 's/^[[:space:]]*(export[[:space:]]+)?//; s/=.*$//' | sort -u
}

# Names in .env.example that the repo's env file doesn't have (names only, rule A6, D54).
check_env_names() { # <repo> <path> <env file name>
  local repo="$1" path="$2" envname="$3" example="" f missing count shown
  for f in .env.example .env.sample; do [ -f "$path/$f" ] && { example="$f"; break; }; done
  [ -n "$example" ] || return 0
  missing="$(comm -23 <(env_names "$path/$example") <(env_names "$path/$envname"))"
  if [ -z "$missing" ]; then
    ok "$envname has every variable $example lists (names only)"
    return 0
  fi
  count="$(printf '%s\n' "$missing" | grep -c .)"
  shown="$(printf '%s\n' "$missing" | head -15 | tr '\n' ' ' | sed 's/ $//; s/ /, /g')"
  [ "$count" -gt 15 ] && shown="$shown, and $((count - 15)) more"
  echo "⚠️ $repo/$envname is missing $count variable(s) that $example has: $shown"
  to_look=$((to_look + 1))
  echo "   The app or its tests may fail until they're added."
  echo "   How to fix it (you change the file yourself; the AI never sees it):"
  how_to_open "$path/$envname"
  echo "   2. Add these lines, each with the value from your team (or from $example if it's only an example value):"
  printf '%s\n' "$missing" | head -15 | sed 's/$/=/; s/^/        /'
  [ "$count" -gt 15 ] && echo "        … and $((count - 15)) more (see $example)"
  echo "   3. Save, then run $CMD $repo again."
}

is_this_mac() { case "$1" in localhost|127.0.0.1|::1|'[::1]'|0.0.0.0) return 0 ;; *) return 1 ;; esac; }

check_env_points_here() { # <repo> <path> <env file> <services list>
  local repo="$1" path="$2" envf="$2/$3" services="$4" issues="" lines="" v host port url rest scheme useport
  local redis_from rabbit_from redis_port rabbit_port
  eval "redis_from=\${USED_FROM_redis:-}; redis_port=\${USED_PORT_redis:-$LOCAL_REDIS_PORT}"
  eval "rabbit_from=\${USED_FROM_rabbitmq:-}; rabbit_port=\${USED_PORT_rabbitmq:-$LOCAL_RABBITMQ_PORT}"

  if has_item "$services" redis || has_item "$services" bullmq; then
    host="$(env_value "$envf" REDIS_HOST)"; port="$(env_value "$envf" REDIS_PORT)"
    if [ -z "$host" ]; then issues="$issues|REDIS_HOST isn't set"
    elif ! is_this_mac "$host"; then issues="$issues|REDIS_HOST points somewhere else, not to this Mac"; fi
    if [ -z "$port" ]; then issues="$issues|REDIS_PORT isn't set"
    elif [ "$port" != "$redis_port" ]; then issues="$issues|REDIS_PORT isn't the port of your local Redis ($redis_port)"; fi
    if env_has_key "$envf" REDIS_USE_TLS; then
      case "$(env_value "$envf" REDIS_USE_TLS)" in ''|false|0|no) ;; *) issues="$issues|REDIS_USE_TLS is on, but a local Redis doesn't use TLS" ;; esac
    fi
    if [ -n "$host" ] && [ -n "$port" ]; then
      if [ "$(redis_reply "$host" "$port" PING | head -1)" = "+PONG" ] || redis_reply "$host" "$port" PING | grep -q NOAUTH; then
        is_this_mac "$host" && ok "$3: Redis points to this Mac, and it answers" || info "(The Redis your $3 points to answers, but it isn't the one on this Mac.)"
      else
        is_this_mac "$host" && issues="$issues|the Redis that $3 points to doesn't answer"
      fi
    fi
    lines="$lines|REDIS_HOST=127.0.0.1|REDIS_PORT=$redis_port"
    if [ "$redis_from" = "docker" ] && [ "$(docker_copy redis | awk '{print $1}')" != "closio-agent-redis" ]; then
      lines="$lines|REDIS_USER=  and  REDIS_PASSWORD=   (the user and password you gave your own Docker Redis; empty if none)"
    else
      lines="$lines|REDIS_USER=|REDIS_PASSWORD="
    fi
    env_has_key "$envf" REDIS_USE_TLS && lines="$lines|REDIS_USE_TLS=false"
  fi

  if has_item "$services" rabbitmq; then
    url="$(env_value "$envf" RABBITMQ_URL)"
    if [ -z "$url" ]; then
      issues="$issues|RABBITMQ_URL isn't set"
    else
      scheme="${url%%://*}"; rest="${url#*://}"; rest="${rest#*@}"; rest="${rest%%/*}"
      host="${rest%:*}"; useport="${rest##*:}"
      [ "$host" = "$rest" ] && useport=""
      case "$scheme" in amqps) issues="$issues|RABBITMQ_URL uses amqps (TLS), but a local RabbitMQ doesn't use TLS" ;; esac
      [ -z "$useport" ] && useport=5672
      if ! is_this_mac "$host"; then issues="$issues|RABBITMQ_URL points somewhere else, not to this Mac"
      elif [ "$useport" != "$rabbit_port" ]; then issues="$issues|RABBITMQ_URL doesn't use the port of your local RabbitMQ ($rabbit_port)"
      elif port_answers "$host" "$useport"; then ok "$3: RabbitMQ points to this Mac, and it answers"
      else issues="$issues|the RabbitMQ that $3 points to doesn't answer"; fi
    fi
    if [ "$rabbit_from" = "docker" ] && [ "$(docker_copy rabbitmq | awk '{print $1}')" != "closio-agent-rabbitmq" ]; then
      lines="$lines|RABBITMQ_URL=amqp://<user>:<password>@127.0.0.1:$rabbit_port   (the user and password of your own Docker RabbitMQ)"
    else
      lines="$lines|RABBITMQ_URL=amqp://guest:guest@127.0.0.1:$rabbit_port   (guest / guest is a local RabbitMQ's built-in login; it only works from this Mac)"
    fi
  fi

  [ -n "$issues" ] || return 0
  local i
  echo "$issues" | tr '|' '\n' | while IFS= read -r i; do
    [ -n "$i" ] || continue
    echo "⚠️ $repo/$3: $i"
  done
  to_look=$((to_look + $(echo "$issues" | tr '|' '\n' | grep -c .)))
  echo "   How to fix it (you change the file yourself; the AI never sees it):"
  how_to_open "$envf"
  echo "   2. Note down the old values first, if you'll need them again (e.g. for the dev server)."
  echo "   3. Set these lines for your local copies:"
  echo "$lines" | tr '|' '\n' | while IFS= read -r i; do [ -n "$i" ] && echo "        $i"; done
  echo "   4. Save, then run $CMD $repo again."
}

# ---------------------------------------------------------------- one repo

claude_has_folder() { # <path>
  [ -f "$CLAUDE_LOCAL_SETTINGS" ] && jq -e --arg p "$1" '(.permissions.additionalDirectories // []) | index($p)' "$CLAUDE_LOCAL_SETTINGS" >/dev/null 2>&1
}

add_claude_folder() { # <path>: adds it to permissions.additionalDirectories, keeping everything else
  local tmp="$CLAUDE_LOCAL_SETTINGS.tmp"
  mkdir -p "$(dirname "$CLAUDE_LOCAL_SETTINGS")"
  [ -s "$CLAUDE_LOCAL_SETTINGS" ] || echo '{}' > "$CLAUDE_LOCAL_SETTINGS"
  if jq --arg p "$1" '.permissions = (.permissions // {}) | .permissions.additionalDirectories = (((.permissions.additionalDirectories // []) + [$p]) | unique)' \
    "$CLAUDE_LOCAL_SETTINGS" > "$tmp" 2>/dev/null; then
    mv "$tmp" "$CLAUDE_LOCAL_SETTINGS"
  else
    rm -f "$tmp"; return 1
  fi
}

install_needed() { # <path> <language>
  [ "$2" = "node" ] || return 0
  [ -d "$1/node_modules" ] || return 0
  if [ -f "$1/package-lock.json" ]; then
    [ -f "$1/node_modules/.package-lock.json" ] || return 0
    [ "$1/package-lock.json" -nt "$1/node_modules/.package-lock.json" ] && return 0
  elif [ -f "$1/yarn.lock" ]; then
    [ -f "$1/node_modules/.yarn-integrity" ] || return 0
    [ "$1/yarn.lock" -nt "$1/node_modules/.yarn-integrity" ] && return 0
  fi
  return 1
}

test_summary() { # <log>: the result lines of mocha / vitest / go test
  grep -E '^[[:space:]]*[0-9]+ (passing|failing|pending)|^[[:space:]]*(Test Files|Tests)[[:space:]]|^(ok|FAIL|PASS)[[:space:]]' "$1" | tail -6 | sed 's/^[[:space:]]*/   /'
}

setup_one() { # <repo> <option>
  local repo="$1" option="$2" file lfile path want have lang nv envname services install_cmd test_cmd log rc branch changes
  local fix_before="$to_fix" look_before="$to_look" tests_result="not run"
  CURRENT_REPO="$repo"
  ENV_OPENED=""
  echo
  echo "━━ $repo"
  file="$(shared_file "$repo")"; lfile="$(local_file "$repo")"
  path="$(yaml_get "$lfile" local_path)"

  # 1. The clone (never cloned by the agent, D53)
  if [ ! -f "$lfile" ]; then
    bad "Where $repo is on this Mac isn't saved yet" "Run /flow-configure-repo $repo (give your clone's path)."
    return 1
  elif [ -z "$path" ]; then
    bad "$repo isn't cloned on this Mac" "Cloning is manual: on the VPN, git clone $(yaml_get "$file" gitlab_url) <your workspace folder>/$repo, then run /flow-configure-repo $repo path <that folder>."
    return 1
  elif [ ! -d "$path/.git" ]; then
    bad "$repo: clone not found at $path" "Run /flow-configure-repo $repo path <new path>."
    return 1
  fi
  want="$(yaml_get "$file" gitlab_path)"
  have="$(gitlab_path_of "$(git -C "$path" remote get-url origin 2>/dev/null)")"
  if [ "$want" != "$have" ]; then
    bad "$path is a clone of '${have:-no GitLab remote}', not '$want'" "Run /flow-configure-repo $repo path <the right clone>."
    return 1
  fi
  ok "Clone: $path"

  # 2. Branch: only shown. Branches, pulls and stashes are the card phases' job (D54).
  branch="$(git -C "$path" branch --show-current 2>/dev/null)"
  changes="$(git -C "$path" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  info "Branch: ${branch:-(detached)} · $changes uncommitted change(s). Left as they are: the card phases handle branches."

  mkdir -p "$LOGS_DIR"
  log="$LOGS_DIR/setup-$repo.log"
  printf '# flow-setup-repo log for %s, %s. Private (local/ is never pushed).\n' "$repo" "$(date '+%Y-%m-%d %H:%M:%S')" > "$log"

  # 3. Node: the repo's own version, installed with nvm if missing (rule A13, D52)
  lang="$(yaml_get "$file" language)"; lang="${lang:-node}"
  nv="$(yaml_get "$file" node_version)"; [ "$nv" = "none" ] && nv=""
  if [ "$lang" = "node" ] && [ -n "$nv" ]; then
    if [ -z "$(nvm_sh)" ]; then
      bad "nvm isn't installed, so Node $nv can't be used for $repo" "Install nvm (setup guide, section 1), then run $CMD $repo again."
      return 1
    fi
    if ! ls -d "$NVM_DIR/versions/node/v$nv."* >/dev/null 2>&1; then
      info "Node $nv isn't installed yet. Installing it with nvm..."
      if run_in_repo "$path" "" 600 "$log" ". \"$(nvm_sh)\" && nvm install $nv"; then
        ok "Node $nv installed with nvm"
      else
        bad "Couldn't install Node $nv with nvm" "Run 'nvm install $nv' in a terminal, then run $CMD $repo again. Details: local/logs/setup-$repo.log"
        return 1
      fi
    fi
    local used
    used="$(/bin/bash -c '. "$1" >/dev/null 2>&1; nvm use "$2" >/dev/null 2>&1 && node -v' _ "$(nvm_sh)" "$nv")"
    if [ -n "$used" ]; then ok "Node $used (what $repo is built for: $nv)"
    else bad "Couldn't switch to Node $nv" "Run 'nvm install $nv' in a terminal, then run $CMD $repo again."; return 1; fi
  fi

  # 4. Env file: name only, never read by the AI (rule A6)
  envname="$(yaml_get "$file" env_file)"
  services="$(yaml_get "$file" local_services)"
  local env_ok=""
  if [ -z "$envname" ] || [ "$envname" = "none" ]; then
    env_ok=""
  elif [ -f "$path/$envname" ]; then
    ok "Env file: $envname is there (its values are never shown)"
    env_ok="yes"
    check_env_names "$repo" "$path" "$envname"
  else
    echo "❌ $repo: $envname is missing"
    echo "   How to fix it:"
    echo "   1. Ask your team for this repo's $envname (local values)."
    echo "   2. Save it as $path/$envname (never paste it into the AI chat)."
    if [ -f "$path/.env.example" ]; then
      echo "      If the team has no copy, start from the example: in the repo folder run  cp .env.example $envname  and fill in the values."
    fi
    echo "   3. Run $CMD $repo again."
    to_fix=$((to_fix + 1))
  fi

  # 5. Install the packages, only when needed (D54)
  install_cmd="$(yaml_get "$file" install_command)"
  local installed="yes"
  if [ -z "$install_cmd" ] || [ "$install_cmd" = "none" ]; then
    :
  elif [ "$option" = "install" ] || install_needed "$path" "$lang"; then
    info "Installing packages ($install_cmd)..."
    run_in_repo "$path" "$nv" "$SETUP_INSTALL_TIMEOUT" "$log" "$install_cmd"
    rc=$?
    if [ "$rc" -eq 0 ]; then
      ok "Packages installed ($install_cmd)"
    elif [ "$rc" -eq 124 ]; then
      bad "Installing packages took longer than $SETUP_INSTALL_TIMEOUT seconds and was stopped" "Check your internet connection, then run $CMD $repo install. Details: local/logs/setup-$repo.log"
      installed=""
    else
      bad "Installing packages failed ($install_cmd)" "Read the end of local/logs/setup-$repo.log, fix what it says, then run $CMD $repo install."
      tail -8 "$log" | sed 's/^/        /'
      installed=""
    fi
  else
    ok "Packages already installed and up to date"
  fi

  # 6. Local Redis and RabbitMQ (D21, D54)
  NEEDS_BULLMQ=""; has_item "$services" bullmq && NEEDS_BULLMQ="yes"
  local need=""
  { has_item "$services" redis || has_item "$services" bullmq; } && need="redis"
  has_item "$services" rabbitmq && need="$need rabbitmq"
  local s
  for s in $need; do setup_service "$s"; done
  [ -z "$need" ] && ok "Local services: none needed"

  # 7. Does the repo's .env point to them? Values are never shown (D54, rule A6)
  if [ -n "$need" ] && [ -n "$env_ok" ]; then
    check_env_points_here "$repo" "$path" "$envname" "$services"
  fi

  # 8. Tests, once (not the coverage check: that's Phase 6). Time limit in config/project-settings.sh.
  test_cmd="$(yaml_get "$file" test_command)"
  if [ -z "$test_cmd" ] || [ "$test_cmd" = "none" ]; then
    ok "No test suite in $repo, so no tests to run"
    tests_result="no test suite"
  elif [ -z "$installed" ]; then
    look "Tests not run, because installing the packages failed" "Fix the install first (see above)."
  else
    info "Running the tests ($test_cmd, time limit $SETUP_TEST_TIMEOUT s)..."
    run_in_repo "$path" "$nv" "$SETUP_TEST_TIMEOUT" "$log" "$test_cmd"
    rc=$?
    if [ "$rc" -eq 0 ]; then
      ok "Tests passed"
      tests_result="passed"
    elif [ "$rc" -eq 124 ]; then
      bad "The tests took longer than $SETUP_TEST_TIMEOUT seconds and were stopped" \
        "Run them yourself to see why: cd \"$path\" && nvm use $nv && $test_cmd. The limit is SETUP_TEST_TIMEOUT in config/project-settings.sh."
      tests_result="timed out"
    else
      bad "Tests failed" "Read local/logs/setup-$repo.log. If the errors mention a database or a host that can't be reached, connect the VPN (/flow-vpn connect) and run $CMD $repo again; if they're real test failures, they come from the repo's current branch."
      tests_result="failed"
    fi
    test_summary "$log"
    # On a failure, the end of the test output (not the install part)
    [ "$tests_result" = "passed" ] || awk '/^\$ /{buf=""} {buf=buf $0 "\n"} END{printf "%s", buf}' "$log" | tail -12 | sed 's/^/        /'
    info "Full output: local/logs/setup-$repo.log"
  fi

  # 9. Folder access for Claude Code (personal .claude/settings.local.json, D42, D54)
  if claude_has_folder "$path"; then
    ok "Claude Code can already use $path"
  elif add_claude_folder "$path" && claude_has_folder "$path"; then
    ok "Claude Code can now use $path (added to your personal .claude/settings.local.json)"
  else
    bad "Couldn't add $path to .claude/settings.local.json" "Check that the file is valid JSON (jq . .claude/settings.local.json), then run $CMD $repo again."
  fi

  # 10. Save the result (private)
  yaml_set "$lfile" setup_on "$(date '+%Y-%m-%d %H:%M')"
  yaml_set "$lfile" setup_tests "$tests_result"
  echo "Result for $repo: $((to_fix - fix_before)) to fix, $((to_look - look_before)) to look at."
  [ "$to_fix" -eq "$fix_before" ]
}

# ---------------------------------------------------------------- list (only reads)

list_repos() {
  local f repo path state tests n=0 lang
  echo "Repo setup on this Mac (flow-setup-repo)"
  for f in "$REPOS_DIR"/*.yaml; do
    [ -f "$f" ] || continue
    repo="$(basename "$f" .yaml)"; n=$((n + 1))
    path="$(yaml_get "$(local_file "$repo")" local_path)"
    lang="$(yaml_get "$f" language)"
    if [ -z "$path" ] || [ ! -d "$path/.git" ]; then
      echo "⚠️ $repo: not on this Mac (or its path isn't saved)"
      echo "   Tip: Clone it yourself, then /flow-configure-repo $repo path <folder>."
      continue
    fi
    state="$(yaml_get "$(local_file "$repo")" setup_on)"
    tests="$(yaml_get "$(local_file "$repo")" setup_tests)"
    if [ -z "$state" ]; then
      echo "⚠️ $repo: cloned, not set up yet"
      echo "   Tip: Run $CMD $repo"
    else
      if [ "${lang:-node}" = "node" ] && [ ! -d "$path/node_modules" ]; then
        echo "⚠️ $repo: set up on $state, but its packages are gone"
        echo "   Tip: Run $CMD $repo"
      else
        case "$tests" in
          failed|"timed out") echo "⚠️ $repo: set up on $state, but its tests $tests"
                              echo "   Tip: See local/logs/setup-$repo.log, then run $CMD $repo again." ;;
          *) echo "✅ $repo: set up on $state · tests: ${tests:-not run} · services: $(yaml_get "$f" local_services)" ;;
        esac
      fi
    fi
  done
  [ "$n" -eq 0 ] && echo "⚠️ No repos registered yet. Run /flow-configure-repo first."
  echo
  echo "Saved choice for when you have both a Homebrew and a Docker copy: Redis: ${LOCAL_REDIS_FROM:-none} · RabbitMQ: ${LOCAL_RABBITMQ_FROM:-none}"
}

codex_start_command() {
  local f repo path s=""
  for f in "$LOCAL_REPOS_DIR"/*.yaml; do
    [ -f "$f" ] || continue
    [ -n "$(yaml_get "$f" setup_on)" ] || continue
    path="$(yaml_get "$f" local_path)"
    [ -n "$path" ] && s="$s --add-dir \"$path\""
  done
  [ -n "$s" ] || return 0
  echo
  echo "Codex: to let it work in these repos, start it from the closio-agent folder with:"
  echo "   codex$s"
}

# ---------------------------------------------------------------- main

check_folder() {
  if [ "$(pwd -P)" = "$AGENT_ROOT" ]; then
    ok "Started in the closio-agent folder"
  else
    bad "Not started in the closio-agent folder (current folder: $(pwd))" \
      "Quit, open a terminal in $AGENT_ROOT, run 'nvm use v$NODE_MAJOR', then start Claude Code or Codex again." \
      "Always start Claude Code or Codex in the closio-agent folder."
    exit 1
  fi
}

finish_run() {
  # Docker Desktop was only started to look and nothing uses it: quit it again (D54).
  if [ "$DOCKER_STATE" = "started-by-us" ] && [ -z "$DOCKER_USED" ]; then
    "$OSASCRIPT" -e 'quit app "Docker"' >/dev/null 2>&1 && info "Quit Docker Desktop again (it was only started to look for Docker copies)."
  fi
  codex_start_command
  echo
  echo "Result: $to_fix to fix, $to_look to look at."
  [ "$to_fix" -eq 0 ]
}

case "${1:-}" in
  check-folder) check_folder ;;
  list) list_repos ;;
  run)
    [ $# -ge 2 ] || { echo "Usage: bash scripts/setup-repo.sh run <repo|all> [install|services]"; exit 1; }
    target="$2"; option="${3:-}"
    case "$option" in ''|install|services) ;; *) bad "Unknown option '$option'" "Use install or services, or nothing."; exit 1 ;; esac
    [ "$option" = "services" ] && FORGET_CHOICE="yes"
    mkdir -p "$LOGS_DIR"
    if [ "$target" = "all" ]; then
      repos=""
      for f in "$REPOS_DIR"/*.yaml; do
        [ -f "$f" ] || continue
        r="$(basename "$f" .yaml)"
        p="$(yaml_get "$(local_file "$r")" local_path)"
        if [ -n "$p" ] && [ -d "$p/.git" ]; then repos="$repos $r"; else info "Skipping $r: not cloned on this Mac."; fi
      done
      [ -n "$repos" ] || { bad "No repo is cloned on this Mac yet" "Clone one yourself, then /flow-configure-repo <repo> path <folder>."; exit 1; }
      echo "flow-setup-repo — setting up:$repos"
      for r in $repos; do setup_one "$r" "$option"; done
    else
      valid_repo_name "$target" || { bad "'$target' isn't a valid repo name" "Use the repo's folder name, e.g. nodejs-ws2closio, or 'all'."; exit 1; }
      [ -f "$(shared_file "$target")" ] || { bad "$target isn't registered" "Register it first: /flow-configure-repo <path of its clone>."; exit 1; }
      echo "flow-setup-repo — setting up $target"
      setup_one "$target" "$option"
    fi
    finish_run ;;
  *) echo "Usage: bash scripts/setup-repo.sh check-folder | list | run <repo|all> [install|services]"; exit 1 ;;
esac
