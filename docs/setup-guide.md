# Setup Guide — closio-agent for Japfa (Closio)

> **Status (2026-10-19):** every command of `closio-agent` is built, and they're being tried on real cards: the setup and everyday commands `flow-ping`, `flow-doctor`, `flow-vpn`, `flow-configure-user`, `flow-configure-repo`, `flow-setup-repo`, `flow-memory`, `flow-check-card` and `flow-help`, `flow-grill` (any time) ([commands.md](commands.md)), and the card commands `flow-status`, `flow-start`, `flow-develop`, `flow-verify`, `flow-ac-check`, `flow-push`, `flow-review`, `flow-finish` and `flow-qa`: every card phase. `flow-configure-user` also sets up Playwright, for checking web cards (it asks before that download).
>
> **Use the commands first** (see "First-time setup, in order" below, or the plain-words walkthrough in [user-guide.md](user-guide.md)). The manual steps in this guide stay as a backup and explain what the commands do. Steps marked **✅ verified** were tested on a real Mac (macOS 26.6.2). Steps marked **🛠 planned** aren't built yet.
>
> **Golden rule:** never paste a password, token or secret into the Claude Code or Codex chat. Anything typed there is sent to the AI provider and stays in the session history. Secrets go into the **macOS Keychain** only, using the commands below in your **own terminal**.

---

## 1. What you need before starting

### Accounts and access

| What | Details |
|---|---|
| **Jira** | Access to `https://productclosio.atlassian.net`, project **Closio** (key **`SCRUM`**) |
| **GitLab** | An account on the Japfa GitLab `https://jcvs.japfacomfeed.co.id`, with access to the repos in [section 6](#6-repositories) |
| **VPN** | Japfa VPN access through **SSO**: the same account you use in the FortiClient app |
| **AI tool** | Claude Code and/or Codex (`closio-agent` commands all start with `flow-`: `/flow-start` in Claude Code, `$flow-start` in Codex; see [D16](design-decisions.md#d16), [D43](design-decisions.md#d43)) |
| **Test logins** | Your personal test credentials for the Closio web app and the WS1 login API, which are different ([section 5](#5-store-your-secrets-in-the-macos-keychain)) |
| **Repo `.env` files** | Each repo's `.env` (from your team) holds its service credentials and the dev PostgreSQL credentials ([D34](design-decisions.md#d34)) |

### Tools on your Mac

| Tool | Why | Install |
|---|---|---|
| [Homebrew](https://brew.sh) | Installs the other tools | See brew.sh |
| git | Repos | Comes with the Xcode command-line tools (`xcode-select --install`) |
| [nvm](https://github.com/nvm-sh/nvm) + **Node.js v22** (+ any version a repo needs) | Claude Code, Codex and closio-agent's scripts run on Node 22 ([D41](design-decisions.md#d41)). Each code repo runs on the Node version it's built for ([D52](design-decisions.md#d52)); the 7 current repos all use 22 | Install nvm, then `nvm install 22`. If `flow-doctor` says a repo's version is missing: `nvm install <version>` |
| Docker **or** Homebrew copies | Local **Redis** and **RabbitMQ** for backend tests ([D21](design-decisions.md#d21), [D54](design-decisions.md#d54)). `flow-setup-repo` uses whichever you have (section 7) | Docker Desktop, or `brew install redis rabbitmq` |
| openfortivpn | VPN from the command line ([D14](design-decisions.md#d14)) | [Section 2](#2-vpn--verified) |
| Claude Code | Runs `closio-agent` | **Inside Node v22 with npm**, see [below](#install-claude-code-and-codex-inside-node-v22--verified) |
| Codex (optional) | Runs `closio-agent` | **Inside Node v22 with npm**, see [below](#install-claude-code-and-codex-inside-node-v22--verified) |

### Get closio-agent (one-time)

The repo is **private** on GitHub, so ask Manas to add your GitHub account first. Then, in the folder where you keep your projects:

```bash
git clone https://github.com/manas-shurutech-04/closio_agent.git closio-agent
```

The `closio-agent` at the end names the folder the way these docs expect. Without it, git would call it `closio_agent`.

### Install Claude Code and Codex (inside Node v22) ✅ verified

Both tools are installed with npm **inside Node v22**. That way there's only one copy of each on your Mac, and both follow the Node v22 rule ([D41](design-decisions.md#d41)). Your logins and settings are kept, because they live in `~/.claude` and `~/.codex`, not in the install.

1. Close any open Claude Code or Codex window.
2. Switch to Node 22:
   ```bash
   nvm use v22
   ```
3. Install Claude Code (never with `sudo`):
   ```bash
   npm install -g @anthropic-ai/claude-code
   ```
4. Install Codex, if you use it (never with `sudo`):
   ```bash
   npm install -g @openai/codex
   ```
5. Remove any other copy. If you installed them with Homebrew before (`brew list --cask` shows `claude-code` or `codex`):
   ```bash
   brew uninstall --cask claude-code
   brew uninstall --cask codex
   ```
6. Check. Both should be under `~/.nvm/versions/node/v22…/bin/`:
   ```bash
   which claude codex
   claude --version
   codex --version
   ```
7. **Codex only:** restart its background service from this same terminal:
   ```bash
   codex app-server daemon restart
   ```
   Codex runs its commands through a background service that keeps running between sessions. It keeps the Node version it was started with, even if you run `nvm use v22` later. Restarting it from a Node v22 terminal makes it use Node 22.

   > **Watch out: Codex's updater.** Codex also has a separate updater process that keeps Codex up to date. It also keeps the Node version it was started with. If it was started with another Node (on the first test Mac it was v18), it can bring the background service back on that Node, for example after Codex updates itself. So if `$flow-doctor` in Codex shows the wrong Node again, repeat step 7. (How to restart the updater itself hasn't been checked yet.)

**Upgrading later:** run `nvm use v22`, then `npm install -g @anthropic-ai/claude-code@latest` or `npm install -g @openai/codex@latest`. After a Codex upgrade, do step 7 again to be safe.

### How to start Claude Code or Codex (every time)

```bash
cd path/to/closio-agent
nvm use v22
claude        # or: codex
```

- **Always start in the closio-agent folder** ([D42](design-decisions.md#d42), rule A10). The agent's commands only load from there. Don't start the tool inside a code repo: the agent adds the repos it needs as extra folders itself. (Today the folder is still called `AI Pipeline`.)
- **Always run `nvm use v22` first** ([D41](design-decisions.md#d41), rule A9). closio-agent, Claude Code and Codex run on Node v22; each code repo runs on its own Node version, which the agent switches to itself (rule A13, [D52](design-decisions.md#d52)). All agent rules: [agent-rules.md](agent-rules.md).
- The setup commands (`flow-configure-user`, `flow-configure-repo`, `flow-setup-repo`) remind you of this and stop if the session wasn't started in the closio-agent folder; `flow-doctor` checks it too.
- The Claude desktop app doesn't start from a terminal, so you can't run `nvm use v22` there first. `flow-doctor` shows it if Node isn't 22. When the agent runs anything in a code repo (`flow-setup-repo`), its script switches to that repo's Node version itself first (rule A13), so that works in the desktop app too ([D54](design-decisions.md#d54)).

### Approval prompts in Claude Code

The first time you start Claude Code in this folder, it asks whether you trust it. Say yes: that turns on the shared file `.claude/settings.json`, which lets Claude Code run every script the flow commands use without asking you ([D49](design-decisions.md#d49), [D57](design-decisions.md#d57)). Anything else still asks. It also turns on the suggestions while you type a flow command (`.claude/skills/flow-autocomplete/`, [D73](design-decisions.md#d73)); `claude plugin list` in this folder shows `flow-autocomplete@skills-dir` as loaded.

**Codex:** when Codex asks whether to trust this folder, say yes too. Then the shared file `.codex/rules/closio-agent.rules` lets Codex run the same scripts without asking (Codex calls these "rules"; they're still experimental).

**The card hooks ([D86](design-decisions.md#d86), [D87](design-decisions.md#d87), [D91](design-decisions.md#d91)):** a prompt hook adds closio-agent's card rules (`rulesets/card-rules.md`) to every prompt about a card (and, after the conversation was summarized, asks for the rules to be read again), and an end-of-reply hook saves the card's folder to its branch on GitHub after every reply. In Claude Code they're on once you've trusted the folder (`.claude/settings.json`). **In Codex, approve them once** (`.codex/hooks.json`); Codex skips a hook until you have, and asks again whenever the hook file changes: (1) start Codex in the closio-agent folder (after `nvm use v22`); it says "… hooks need review before they can run"; (2) type `/hooks`; (3) in the list, select the hooks under "When the user submits a prompt" and "After context compaction" (`bash scripts/card-rules-hook.sh`) and "Right before Codex ends its turn" (`bash scripts/card-autosave-hook.sh`) and "Before a tool executes" (`bash scripts/command-guard-hook.sh codex`, the command guard, [D94](design-decisions.md#d94)) and approve them; (4) send any prompt that names a card (e.g. "Is SCRUM-567 picked up?"), then `$flow-doctor`: "Codex: the hooks are trusted and have run" shows ✅. Until then `/flow-doctor`'s "Card hooks" section shows a ⚠️ with these steps (when your AI tools include Codex), also after the hook file changed.

### First-time setup, in order

1. Get closio-agent and install the tools (above).
2. Start Claude Code or Codex the right way (above).
3. `/flow-ping`: are the commands loaded?
4. `/flow-doctor`: what's missing?
5. `/flow-configure-user`: your personal settings and secrets. Optional: the Jira API backup (section 3.1).
6. `/flow-configure-repo`: for each repo you work on, where your clone is and its dev keys.
7. `/flow-setup-repo all`: gets every repo you've cloned ready (Node version, packages, local Redis and RabbitMQ, `.env` check, tests, folder access).
8. `/flow-vpn connect`, then `/flow-doctor` again: everything should be ✅ or ⚠️.
9. Any time: `/flow-help` shows every command and how it's typed.

### Check that the flow commands work

In the session you just started, type (Codex: use `$` instead of `/`):

1. `/flow-ping`: should answer "flow commands are loaded in …".
2. `/flow-doctor`: shows ✅ (fine), ⚠️ (worth a look) or ❌ (must fix) for each check, with the steps to fix each ⚠️ and ❌ ([commands.md](commands.md#flow-doctor)). Run it again after every fix.

If something is wrong:

| Problem | Fix |
|---|---|
| Claude Code doesn't list the flow commands | Run `bash scripts/link-claude-skills.sh` in the closio-agent folder and try again |
| `flow-doctor` shows the wrong Node in **Claude Code** | Quit, run `nvm use v22`, start `claude` again |
| `flow-doctor` shows the wrong Node in **Codex** (e.g. v18), even after `nvm use v22` | Codex's background service was started with another Node. Close Codex, then in a terminal run `nvm use v22` and `codex app-server daemon restart`, and start `codex` again. If it comes back later (e.g. after Codex updates itself), do the same again |

---

### Test closio-agent itself

Changing a script, a command or a rule of closio-agent? Run its own tests before you commit ([D92](design-decisions.md#d92), [D93](design-decisions.md#d93), build rule R20). Start Docker Desktop, then from the closio-agent folder, in a terminal or in the AI tool:

```bash
bash tests/run.sh --docker --coverage
```

- **About 25 seconds**, in a Linux container with the Mac's own bash 3.2. The first run builds the test image (it downloads about 90 MB, once); it's built again by itself only when `tests/docker/` changes. A few tools work differently on Linux (`sed`, `stat`, `date`, `fold`, `script`): the image has small stand-ins that take the Mac's form, so the scripts and tests stay the same.
- **Without Docker Desktop:** `bash tests/run.sh --coverage` runs the same tests on the Mac itself. It takes about 11 minutes on a Mac with security software (every program it starts is checked).
- **Nothing to install** besides Docker Desktop, nothing real is touched: the tests use bash, git, jq, python3 and curl, and run against fakes (a fake Jira, a fake GitLab, fake remotes, a fake Keychain, stand-ins for `sudo`, `osascript`, `openfortivpn`, `brew`, `docker`…). No AI, no VPN, no real Jira or GitLab, never your `local/`, `runs/`, Keychain or home folder.
- **What you see:** one line per test (✅ or ❌, a failure with what was expected and what came back), then `passed N, failed M`. Exit code 0 when everything passed.
- **Only some tests:** `bash tests/run.sh --docker run.sh jira` runs the test files whose name has one of the words.
- **Coverage:** `--coverage` also shows, per script and in total, the share of its lines the tests ran, and fails under 90% (the lines not run: `local/test-coverage/missed.txt`).
- **Where they are:** `tests/unit/<script>.test.sh` (one file per script), `tests/static/` (the commands and the rules: every command documented and pre-approved, rules numbered, decision links), `tests/flows/` (a card's journey through the scripts), `tests/fakes/`, `tests/lib/` (the runner's helpers), `tests/docker/` (the test image and its stand-ins).

## 2. VPN ✅ verified

GitLab, the dev API and the dev database are **only reachable over the Japfa VPN**. `closio-agent` uses **openfortivpn**, a command-line client, instead of the FortiClient app, so it can connect by itself ([D14](design-decisions.md#d14)).

> **The easy way (built, F3):** in Claude Code type `/flow-vpn connect`, `/flow-vpn status` or `/flow-vpn disconnect` (Codex: `$flow-vpn …`). You only type your Mac password into one macOS dialog and finish the SSO login in your browser. The VPN stays on until you disconnect. The agent also connects by itself at the start of each phase that needs GitLab ([D30](design-decisions.md#d30), [commands.md](commands.md#flow-vpn)).
>
> The manual steps below (2.2–2.5) do the same by hand. Use them if the command doesn't work.

> **Disconnect FortiClient** before using openfortivpn. Two VPN clients connected at once can interfere.

### 2.1 Install openfortivpn (one-time)

```bash
brew install openfortivpn
```

It uses macOS's built-in `/usr/sbin/pppd`; nothing else to install.

### 2.2 Connect

In a terminal (keep it open while you need the VPN):

```bash
sudo openfortivpn vpnwm.japfacomfeed.co.id:443 --realm=sso --saml-login --trusted-cert 142458260b4b0b96bad1fd65db4a58b24d02da43be05620efe476bcff71bfa5e
```

1. Type your **Mac password** (needed for `sudo`).
2. openfortivpn prints a login URL. Open it in your browser:
   `https://vpnwm.japfacomfeed.co.id:443/remote/saml/start?redirect=1&realm=sso`
3. Complete the SSO login. If you're already signed in, it finishes on its own.
4. Wait for **`Tunnel is up and running`**.

What the options mean:
- `--realm=sso` matches the `/sso` in the FortiClient gateway address.
- `--saml-login` handles the SSO login through your browser.
- `--trusted-cert` pins the gateway's certificate. The gateway doesn't send its full certificate chain, so normal validation fails ([D14](design-decisions.md#d14)).

### 2.3 Turn on VPN DNS (each time, after connecting)

macOS apps (git, curl, browsers) ignore the DNS servers openfortivpn sets up, so internal names like the GitLab host wouldn't resolve. In a **second** terminal:

```bash
sudo mkdir -p /etc/resolver && printf "nameserver 10.90.0.53\nnameserver 10.190.0.55\n" | sudo tee /etc/resolver/japfacomfeed.co.id
```

This sends lookups for every `*.japfacomfeed.co.id` host (GitLab, dev API, dev DB) to the VPN's DNS servers ([D27](design-decisions.md#d27)).

### 2.4 Check it works

```bash
curl -s -o /dev/null -w "HTTP %{http_code}\n" https://jcvs.japfacomfeed.co.id/users/sign_in
```

`HTTP 200` means GitLab is reachable.

### 2.5 Disconnect (always remove the DNS file)

1. Press **Ctrl-C** in the openfortivpn terminal. You'll see "Logged out".
2. Remove the DNS file:

```bash
sudo rm -f /etc/resolver/japfacomfeed.co.id
```

**Why removing it matters:** the file covers the whole `japfacomfeed.co.id` domain, including the public VPN gateway `vpnwm.japfacomfeed.co.id`. If it's left in place while the VPN is off, macOS sends the gateway lookup to internal DNS servers it can't reach, so the next connect can fail ([D27](design-decisions.md#d27)).

> Older setups may have a file `/etc/resolver/jcvs.japfacomfeed.co.id` (GitLab only, from an earlier test). It's harmless, but no longer needed: `sudo rm /etc/resolver/jcvs.japfacomfeed.co.id`.

### 2.6 VPN troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `Gateway certificate validation failed, and the certificate digest is not in the local whitelist` | The gateway certificate was renewed (the current one expires **2027-02-03**), so the pinned fingerprint no longer matches | Confirm with the IT/infra team that the new certificate is genuine, then replace the `--trusted-cert` value with the new fingerprint openfortivpn prints |
| `Could not resolve host: jcvs.japfacomfeed.co.id` while connected | The DNS file from 2.3 is missing | Run 2.3 |
| Connecting fails because `vpnwm.japfacomfeed.co.id` can't be resolved | A DNS file was left behind from a previous connection | Run the remove command in 2.5, then connect again |
| The login page doesn't open or never finishes | The SSO login wasn't completed in the browser | Open the printed URL manually and complete the login |

---

## 3. Jira access in the AI tool

| Tool | How | Status |
|---|---|---|
| Claude Code | Claude's **Atlassian** connector (`https://mcp.atlassian.com`), connected to your Atlassian account. It shows as "claude.ai Atlassian MCP" in `claude mcp list` | ✅ verified working on 2026-10-09 |

> **If Jira shows ❌ right after starting Claude Code:** the Atlassian connector can take a while to load, or time out (seen on 2026-10-13: "tools fetch failed — Request timed out"). The flow commands wait and retry for about 30 seconds. If it's still ❌: type `/mcp`, choose "claude.ai Atlassian MCP", then **Reconnect**, and run the command again.
| Codex | **The Atlassian app connected to the ChatGPT account you use for Codex.** Codex then has Jira tools by itself (it shows them as `codex_apps`). How to connect the app in ChatGPT isn't written up here yet. **Other way:** Atlassian's MCP server: `codex mcp add atlassian --url https://mcp.atlassian.com/v2/mcp`, then `codex mcp login atlassian` (approve in the browser), start Codex again, check with `codex mcp list` (steps from Atlassian's docs) | ✅ the ChatGPT app way verified on 2026-10-11 (`$flow-doctor` read project SCRUM). 🛠 The MCP server way is not tested |

### 3.1 The Jira API backup (optional)

When the Jira connector isn't there (it didn't load after the 3 tries, it isn't connected in the account you use, or a Jira tool fails), the commands **switch by themselves** to Jira's REST API and say so in one line: "Jira connector not available: using the Jira API backup." They then do the same things there: read the card and its comments, move it, set its sprint and assignee, post or edit a comment, create a card. Every yes stop stays ([D88](design-decisions.md#d88), rule A31). It needs two things, both optional, set once:

1. **An Atlassian API token.** Open https://id.atlassian.com/manage-profile/security/api-tokens, signed in with the email you use for Jira. Click **Create API token** (not "Create API token with scopes"), name it `closio-agent`, choose its expiry date (at most a year), and copy it.
2. **`/flow-configure-user jira-email`:** type that email (it's not a secret; saved in `local/user-settings.sh`).
3. **`/flow-configure-user jira-api-token`:** a heads-up message, then a hidden macOS box: paste the token there, never in the chat. It goes to the Keychain as `closio-agent.jira-api-token` and is then checked: "✅ The Jira API backup works: signed in as …".

`/flow-doctor` shows it in its "Jira API backup" section: ✅ when Jira accepts it, ⚠️ when it isn't set up (never ❌: it's optional). When the token expires, make a new one and run `/flow-configure-user jira-api-token` again.

---

## 4. GitLab

### 4.1 git access (one-time)

git talks to GitLab over HTTPS, **through the VPN**. On macOS, git stores your GitLab credentials in the Keychain (`credential.helper = osxkeychain`, verified on 2026-10-09). The first time you clone or fetch, git asks for your GitLab credentials and remembers them.

### 4.2 Personal access token (one-time)

`closio-agent` creates the MR and **assigns it to you during the push** (git push options, [D31](design-decisions.md#d31)). Right after, it sets the **full MR description** through the GitLab REST API using **your personal access token** ([D32](design-decisions.md#d32)).

Create the token (VPN connected):

1. In GitLab, go to your avatar → **Preferences** → **Access tokens**. On recent GitLab versions the address is `https://jcvs.japfacomfeed.co.id/-/user_settings/personal_access_tokens`; this address hasn't been checked on the Japfa GitLab.
2. **Add new token**:
   - **Name:** `closio-agent`
   - **Expiration date:** set one (you'll create a new token when it expires)
   - **Scope:** **`api`** (`read_api` can't update MRs)
3. Copy the token, then store it straight away with the command in [section 5](#5-store-your-secrets-in-the-macos-keychain). **Don't paste it anywhere else.**

> **GitLab MCP is not used** ([D32](design-decisions.md#d32)). If you added a GitLab MCP server to Claude Code earlier, remove it, because it times out at every session start: `claude mcp remove "GitLab" -s user`.

---

## 5. Store your secrets in the macOS Keychain

All secrets live in your **login Keychain**, one item per secret ([D33](design-decisions.md#d33)):
- **Service name:** starts with `closio-agent.`
- **Account:** your Mac username (`$USER`)

`closio-agent` scripts read them at run time, so they never appear in the chat, a file or a command line.

> **The easy way (built, F4):** run `/flow-configure-user` (Codex: `$flow-configure-user`). It asks all missing secrets in one go. For each secret, a macOS message first says which one is next ("Copy it now, then click Continue"), then a hidden box opens to paste it into. It goes straight into the Keychain ([commands.md](commands.md#flow-configure-user)).
>
> **Backup:** the terminal commands below do the same by hand. Run them in your **own terminal**, never in the AI chat.

### 5.1 How to add one secret

Run the command. `security` asks you to type the value twice, hidden. Putting `-w` **last** makes it prompt instead of taking the value on the command line, which is what Apple recommends. `-U` updates the item if it already exists.

```bash
security add-generic-password -U -a "$USER" -s "closio-agent.gitlab-token" -l "closio-agent: GitLab personal access token" -w
```

### 5.2 The secrets to add

| Service name | What to enter | Used for |
|---|---|---|
| `closio-agent.gitlab-token` | Your GitLab personal access token (section 4.2) | Setting MR descriptions ([D32](design-decisions.md#d32)) |
| `closio-agent.fe-login-id` | Your login ID for the Closio web app | Playwright tests of `closio-web-v2` ([D20](design-decisions.md#d20)) |
| `closio-agent.fe-login-password` | Your password for the Closio web app | Same |
| `closio-agent.ws1-login-userid` | Your `userid` for the **dev** WS1 login API | Fetching the WS1 session cookie for backend tests: always on the dev WS1, then used on the WS1 on this Mac ([D20](design-decisions.md#d20), [D71](design-decisions.md#d71)) |
| `closio-agent.ws1-login-password` | Your password for the **dev** WS1 login API | Same |
| `closio-agent.jira-api-token` | **Optional:** your Atlassian API token (section 3.1) | The Jira API backup, when the Jira connector isn't there ([D88](design-decisions.md#d88)) |
| `closio-agent.nodejs-ws1closio.ws1-client-id.dev` | WS1's own client ID, which WS1 sends to the WS2s (the value of `WS1_AUTH_CLIENT_ID` in WS1's `.env`) | Every direct WS2 call in the checks sends it, as WS1 does ([D37](design-decisions.md#d37)) |
| `closio-agent.nodejs-ws1closio.ws1-client-secret.dev` | WS1's own client secret (`WS1_AUTH_SECRET_KEY`) | Same |
| `closio-agent.<repo>.ws2-client-id.dev`, `…ws2-client-secret.dev` | **Optional:** only for a WS2 to which WS1 sends another pair (the pricing engine: WS1's `PRICING_ENGINE_CLIENT_ID` / `PRICING_ENGINE_SECRET_KEY`); used instead of WS1's pair for that WS2 | Same |
| `closio-agent.<repo>.db-user.dev`, `closio-agent.<repo>.db-password.dev` | **Optional:** your dev database user and password for that repo | Checking migrations on dev, writing QA steps ([D51](design-decisions.md#d51)) |
| `closio-agent.<repo>.<name>.dev` | Any extra key a repo needs (e.g. a partner API key) | As registered for the repo |

The per-repo keys above are asked by `/flow-configure-repo <repo>` (heads-up, then hidden box); the 5 personal ones by `/flow-configure-user` (the optional `jira-api-token` only when you name it: `/flow-configure-user jira-api-token`).

**Which pair does a WS2 check?** The **caller's**, never a key of the WS2 itself. Each repo that calls a WS2 sends its own client ID and secret in `x-client-id` / `x-client-secret`, and the WS2 checks them against the callers listed in its `SERVICE_CREDENTIALS`. closio-agent's direct WS2 calls act as WS1, so you save **WS1's** pair once, under WS1: what WS1 sends (from its `src/utils/axiosInstances.js`):

| WS2 repo | WS1 sends (variables in WS1's `.env`) | Save as |
|---|---|---|
| `nodejs-ws2targetsalesincentive`, `nodejs-ws2notification` (notifications) | `WS1_AUTH_CLIENT_ID`, `WS1_AUTH_SECRET_KEY` | `/flow-configure-repo nodejs-ws1closio key ws1-client-id` and `… ws1-client-secret` |
| `nodejs-ws2pricingengine` | `PRICING_ENGINE_CLIENT_ID`, `PRICING_ENGINE_SECRET_KEY` | optional: `/flow-configure-repo nodejs-ws2pricingengine key ws2-client-id` and `… ws2-client-secret` |
| `nodejs-ws2closio` | no pair in WS1's code yet | WS1's pair is sent; some WS2 APIs are called by other services, then that caller's pair |

`WS1`'s `INCENTIVE_S2S_CLIENT_ID` / `…_SECRET` are for calls coming **into** WS1, not what it sends.

For each row, run the 5.1 command with that service name and a matching `-l` label.

> The web-app login and the WS1 login are **different** credentials, so store both.
>
> **Not stored in the Keychain** ([D34](design-decisions.md#d34)): each WS2 service's **local** client ID/secret and the dev PostgreSQL credentials. They're already in each repository's `.env` file (**local values only**) and are used from there. Don't paste `.env` contents into an AI chat either; the agent itself never reads `.env` values into the conversation (rule A6).

### 5.3 Check, update, remove

```bash
# Check an item exists (prints nothing secret)
security find-generic-password -a "$USER" -s "closio-agent.gitlab-token" >/dev/null && echo "stored"

# Update: run the add command again (-U replaces the value)

# Remove an item, e.g. when you revoke the token
security delete-generic-password -a "$USER" -s "closio-agent.gitlab-token"
```

How the WS1 session cookie is fetched (done by the agent, shown for reference):
- `POST https://dev-closio-ws1-apiprivate.japfacomfeed.co.id/api/v1/login` (needs the VPN)
- Headers: `accept: application/json`, `X-Secure-Transmission-Type: x`, `X-Application-Version: 1.0.0+1`, `Content-Type: application/json`
- Body: `userid` and `password` from the Keychain, plus `napp_pk: 4` and `client_type: "web"` (the same for everyone)

---

## 6. Repositories

Every repo is added to `closio-agent` through its **repository configuration command** (`flow-configure-repo`, built in F5; [commands.md](commands.md#flow-configure-repo)). For repos already registered, run `/flow-configure-repo <repo>` to tell it where your clone is and to add the repo's dev keys. It is the only way to add a repo and records the full details for each one ([D35](design-decisions.md#d35)). The repos currently in scope ([D23](design-decisions.md#d23)) are below. **All 7 are registered** (2026-10-14): their shared facts are in `config/repos/`. The list isn't fixed: add a new repo any time with `/flow-configure-repo <path of its clone>`. **Each repo runs on its own Node version** (`node_version` in its file; all 7 use 22): if you run anything in a repo yourself, run `nvm use <that version>` first (rule A13, [D52](design-decisions.md#d52)). **Cloning is manual** ([D53](design-decisions.md#d53)): clone a repo yourself on the VPN (`git clone <GitLab address> <folder>`), then tell closio-agent where it is with `/flow-configure-repo <repo> path <folder>`. Remotes are on `https://jcvs.japfacomfeed.co.id/` (VPN needed):

| Repo | GitLab path | Type |
|---|---|---|
| `nodejs-ws1closio` | `closio/backend/nodejs-ws1closio` | BE (BFF) |
| `nodejs-ws2closio` | `closio/backend/nodejs-ws2closio` | BE |
| `nodejs-ws2notification` | `closio/backend/nodejs-ws2notification` | BE |
| `nodejs-ws2pricingengine` | `pricing-engine/backend/nodejs-ws2pricingengine` | BE |
| `nodejs-ws2targetsalesincentive` | `target-sales/backend/nodejs-ws2targetsalesincentive` | BE |
| `ws2jauth` | `genesis-framework/backend-node/ws2jauth` | BE |
| `closio-web-v2` | `closio/frontend-web/closio-web-v2` | FE (Vue) |

**What `flow-configure-repo` records for each repo** ([D51](design-decisions.md#d51)): GitLab address and path, FE/BE and role, base branch, language (node, go or other), Node version (from its Dockerfile), install/run/check/test commands, port and health URL, test format and coverage rules, migrations and seeders (existing Sequelize pattern), queues, local services (Redis, RabbitMQ, BullMQ), the repos it calls, the `.env` file name, which dev keys it needs, MR target branch and optional default labels and reviewers. Not the ruleset: every card follows closio-agent's own `rulesets/story-implementation-workflow.md` ([D64](design-decisions.md#d64)). The shared part is in `config/repos/<repo>.yaml`; where the clone is on your Mac is in `local/repos/<repo>.yaml` (private). Branch names follow one strict rule for every repo: `SCRUM-<number>/<short-description>`, at most 5 words (rule A12).

**Getting a repo ready to work on (built, F6, [D54](design-decisions.md#d54)):** `/flow-setup-repo <repo>` (or `all`), on a repo you've already cloned: switches to the repo's own Node version (installing it with nvm if needed), installs its packages when needed, finds or starts the local Redis and RabbitMQ (section 7), says whether the repo's `.env` points to them and opens it with the lines to set (you change the values yourself), runs its tests once, and gives Claude Code access to the repo folder (Codex: it shows the start command with `--add-dir`). It needs no VPN, never changes branches, and won't clone repos: cloning stays manual ([D53](design-decisions.md#d53)). Details: [commands.md](commands.md#flow-setup-repo).

---

## 7. Local services for backend tests

Per [D21](design-decisions.md#d21):
- **PostgreSQL:** the **dev database**, used directly (VPN needed). The credentials come from the repository's `.env` ([D34](design-decisions.md#d34)).
- **Redis** (all uses, including **BullMQ**, which runs on Redis) and **RabbitMQ**: **local** instances.
- The repos' own `docker-compose.yml` files don't include Redis or RabbitMQ. `flow-setup-repo` checks for both a **Homebrew** and a **Docker** copy before choosing (it starts Docker Desktop if it isn't running, to look, and quits it again if it isn't used): if there's one, it uses it and tells you; if there are both, it asks you once which to use (saved in your `local/user-settings.sh`; `/flow-setup-repo <repo> services` asks again) and stops the other one by itself; if there's none, it suggests one and starts it only after your yes ([D54](design-decisions.md#d54)). Versions: Redis 7 (BullMQ needs 6.2 or newer, with the `noeviction` memory setting) and RabbitMQ 4. The shared Docker file is `config/local-services.yml`.

**Missing variables:** `flow-setup-repo` also compares the variable **names** in the repo's env file with its `.env.example` (never the values). If some are missing, it opens the file and lists the lines to add; you fill in the values from your team.

**What a repo's `.env` needs for the local copies** (`flow-setup-repo` checks it without showing any value, and shows these lines when something doesn't match; you change the file yourself):

| Repos | Lines |
|---|---|
| Redis: `nodejs-ws1closio`, `nodejs-ws2closio`, `nodejs-ws2targetsalesincentive` | `REDIS_HOST=127.0.0.1`, `REDIS_PORT=6379`, `REDIS_USER=` and `REDIS_PASSWORD=` empty (a local Redis has no password), and for targetsales `REDIS_USE_TLS=false` |
| RabbitMQ: `nodejs-ws2notification` | `RABBITMQ_URL=amqp://guest:guest@127.0.0.1:5672` (guest / guest is a local RabbitMQ's built-in login and only works from this Mac) |

With a Docker copy you made yourself (not from `config/local-services.yml`), use its port and the user and password you gave it. Note down the old values before changing them, if you'll need them again.

---

## 8. Security checklist

- [ ] No password, token or secret was ever pasted into an AI chat.
- [ ] The GitLab token has an expiry date and only the `api` scope.
- [ ] If a token was ever exposed (pasted in a chat or command), **revoke it** in GitLab (Preferences → Access tokens), create a new one, and update the Keychain (5.1).
- [ ] After disconnecting the VPN, `/etc/resolver/japfacomfeed.co.id` is removed (2.5).
