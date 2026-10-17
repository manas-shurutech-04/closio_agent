#!/usr/bin/env bash
# Shared helpers: facts about a registered repo, read from its registry files (C4, D67).
# Sourced by scripts/repo-run.sh, scripts/api-call.sh, scripts/db-run.sh and scripts/e2e.sh, after config/project-settings.sh.
# Needs AGENT_ROOT. Never prints a value from a repo's .env file (rule A6): the port is read only to build a local URL
# that the scripts use themselves.

REPOS_DIR="${REPOS_DIR:-$AGENT_ROOT/config/repos}"
LOCAL_REPOS_DIR="${LOCAL_REPOS_DIR:-$AGENT_ROOT/local/repos}"
NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

yaml_get() { # <file> <key>: value of a flat "key: value" line ("" if missing); a " # comment" is dropped
  [ -f "$1" ] || return 0
  grep -m1 -E "^$2:" "$1" | sed -E "s/^$2:[[:space:]]*//; s/[[:space:]]+#.*$//; s/[[:space:]]+$//"
}
repo_file() { echo "$REPOS_DIR/$1.yaml"; }
repo_path() { yaml_get "$LOCAL_REPOS_DIR/$1.yaml" local_path; }
repo_node() { # the repo's Node version ("" for a repo that isn't Node)
  local f nv; f="$(repo_file "$1")"
  case "$(yaml_get "$f" language)" in node|'') nv="$(yaml_get "$f" node_version)" ;; *) nv="" ;; esac
  [ "$nv" = "none" ] && nv=""
  printf '%s' "$nv"
}
nvm_sh() {
  if [ -s "$NVM_DIR/nvm.sh" ]; then echo "$NVM_DIR/nvm.sh"
  elif [ -s /opt/homebrew/opt/nvm/nvm.sh ]; then echo /opt/homebrew/opt/nvm/nvm.sh
  elif [ -s /usr/local/opt/nvm/nvm.sh ]; then echo /usr/local/opt/nvm/nvm.sh
  fi
}
# The repo is registered and cloned here; prints nothing, returns 1 with a reason in REPO_PROBLEM otherwise.
repo_ready() { # <repo>
  REPO_PROBLEM=""
  printf '%s' "$1" | grep -q -E '^[a-z0-9][a-z0-9._-]*$' || { REPO_PROBLEM="'$1' isn't a repo name"; return 1; }
  [ -f "$(repo_file "$1")" ] || { REPO_PROBLEM="$1 isn't registered (run /flow-configure-repo <path of your clone>)"; return 1; }
  local p; p="$(repo_path "$1")"
  if [ -z "$p" ] || [ "$p" = "not-cloned" ] || [ ! -d "$p" ]; then
    REPO_PROBLEM="$1 isn't cloned on this Mac (cloning is manual, D53; then /flow-configure-repo $1 path <folder>)"; return 1
  fi
  return 0
}
# The name of the variable that holds the repo's port, from "port: from the repo's .env (PORT)".
port_var() { yaml_get "$(repo_file "$1")" port | sed -n -E 's/.*\(([A-Z0-9_]+)\).*/\1/p'; }
env_file_of() { local e; e="$(yaml_get "$(repo_file "$1")" env_file)"; printf '%s' "${e:-.env}"; }
# The repo's local port, read from its env file. Used only inside the scripts; never printed.
repo_port() { # <repo>
  local var file line
  var="$(port_var "$1")"; [ -n "$var" ] || return 1
  file="$(repo_path "$1")/$(env_file_of "$1")"; [ -f "$file" ] || return 1
  line="$(grep -m1 -E "^[[:space:]]*(export[[:space:]]+)?$var=" "$file")" || return 1
  printf '%s' "${line#*=}" | sed -E "s/[[:space:]]+#.*$//; s/^[\"']//; s/[\"'][[:space:]]*$//; s/[[:space:]]//g"
}
repo_base_url() { local p; p="$(repo_port "$1")" || return 1; [ -n "$p" ] || return 1; printf 'http://localhost:%s' "$p"; }
repo_health_path() { local h; h="$(yaml_get "$(repo_file "$1")" health_url)"; printf '%s' "${h:-/}"; }
# 0 when anything answers HTTP on the repo's health URL (any status code)
repo_answers() { # <repo>
  local base code
  base="$(repo_base_url "$1")" || return 1
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 "$base$(repo_health_path "$1")" 2>/dev/null)"
  [ -n "$code" ] && [ "$code" != "000" ]
}
