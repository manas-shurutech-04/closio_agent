# Setup Guide — closio-agent for Japfa (Closio)

> **Status (2026-10-10):** `closio-agent` is **in design.** Only the install checks `flow-ping` and `flow-doctor` exist so far ([commands.md](commands.md)). The setup commands (`flow-configure-user`, `flow-configure-repo`, `flow-setup-repo`) will automate most of this guide later.
>
> Until then, this guide explains how to prepare a Mac by hand. Steps marked **✅ verified** were tested on a real Mac on 2026-10-09 (macOS 26.6.2). Steps marked **🛠 planned** describe what the setup commands will do; they're here so you know what to expect.
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
| [nvm](https://github.com/nvm-sh/nvm) + **Node.js v22** | The whole project uses Node v22 ([D41](design-decisions.md#d41)): Claude Code, closio-agent's scripts, and running the repos (their Docker images use `node:22`) | Install nvm, then `nvm install 22` |
| Docker | Local **Redis** and **RabbitMQ** for backend tests ([D21](design-decisions.md#d21)) | Docker Desktop |
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
- **Always run `nvm use v22` first** ([D41](design-decisions.md#d41), rule A9). The whole project uses Node v22.
- 🛠 The setup commands will tell you this and check it.
- 🛠 The Claude desktop app doesn't start from a terminal, so you can't run `nvm use v22` there first. How the agent handles this will be built with its scripts.

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

## 2. VPN ✅ verified

GitLab, the dev API and the dev database are **only reachable over the Japfa VPN**. `closio-agent` uses **openfortivpn**, a command-line client, instead of the FortiClient app, so it can connect by itself ([D14](design-decisions.md#d14)).

> 🛠 **Planned:** a connectivity agent will do steps 2.2–2.5 automatically at the start of each phase. You'll only type your Mac password into a macOS dialog and complete the SSO login in your browser ([D30](design-decisions.md#d30)).

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
| Codex | **The Atlassian app connected to the ChatGPT account you use for Codex.** Codex then has Jira tools by itself (it shows them as `codex_apps`). How to connect the app in ChatGPT isn't written up here yet. **Other way:** Atlassian's MCP server: `codex mcp add atlassian --url https://mcp.atlassian.com/v2/mcp`, then `codex mcp login atlassian` (approve in the browser), start Codex again, check with `codex mcp list` (steps from Atlassian's docs) | ✅ the ChatGPT app way verified on 2026-10-11 (`$flow-doctor` read project SCRUM). 🛠 The MCP server way is not tested |

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

> 🛠 **Planned:** `flow-configure-user` will ask for these and store them for you. Until then, use the commands below in your **own terminal**, not the AI chat.

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
| `closio-agent.ws1-login-userid` | Your `userid` for the WS1 login API | Fetching the WS1 session cookie for backend tests ([D20](design-decisions.md#d20)) |
| `closio-agent.ws1-login-password` | Your password for the WS1 login API | Same |
| `closio-agent.<repo>.ws2-client-id.dev` | **Dev-environment** client ID of that WS2 service, one item per WS2 repo (e.g. `closio-agent.nodejs-ws2closio.ws2-client-id.dev`) | Direct WS2 tests on dev after merge ([D37](design-decisions.md#d37)) |
| `closio-agent.<repo>.ws2-client-secret.dev` | **Dev-environment** client secret of that WS2 service | Same |

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

Every repo is added to `closio-agent` through its **repository configuration command** (`flow-configure-repo`, not built yet). It is the only way to add a repo and records the full details for each one ([D35](design-decisions.md#d35)). The repos currently in scope ([D23](design-decisions.md#d23)) are below. Remotes are on `https://jcvs.japfacomfeed.co.id/` (VPN needed):

| Repo | GitLab path | Type |
|---|---|---|
| `nodejs-ws1closio` | `closio/backend/nodejs-ws1closio` | BE (BFF) |
| `nodejs-ws2closio` | `closio/backend/nodejs-ws2closio` | BE |
| `nodejs-ws2notification` | `closio/backend/nodejs-ws2notification` | BE |
| `nodejs-ws2pricingengine` | `pricing-engine/backend/nodejs-ws2pricingengine` | BE |
| `nodejs-ws2targetsalesincentive` | `target-sales/backend/nodejs-ws2targetsalesincentive` | BE |
| `ws2jauth` | `genesis-framework/backend-node/ws2jauth` | BE |
| `closio-web-v2` | `closio/frontend-web/closio-web-v2` | FE (Vue) |

> 🛠 **Planned:** for each repo, current or new, `flow-configure-repo` records ([D35](design-decisions.md#d35)):
> - name, local path, GitLab remote and project path
> - FE/BE and its role
> - base branch and branch-naming rule
> - install, run and test commands
> - test framework, file layout, patterns and coverage rules (or "no test suite")
> - which `.env` to use
> - local services needed
> - rulesets
>
> `flow-setup-repo` then connects the VPN, clones, installs dependencies, and starts local Redis/RabbitMQ.

---

## 7. Local services for backend tests 🛠 planned

Per [D21](design-decisions.md#d21):
- **PostgreSQL:** the **dev database**, used directly (VPN needed). The credentials come from the repository's `.env` ([D34](design-decisions.md#d34)).
- **Redis** (all uses, including BullMQ) and **RabbitMQ**: **local** instances.
- The repos' own `docker-compose.yml` files don't include Redis or RabbitMQ, so `flow-setup-repo` will provide them with Docker.

---

## 8. Security checklist

- [ ] No password, token or secret was ever pasted into an AI chat.
- [ ] The GitLab token has an expiry date and only the `api` scope.
- [ ] If a token was ever exposed (pasted in a chat or command), **revoke it** in GitLab (Preferences → Access tokens), create a new one, and update the Keychain (5.1).
- [ ] After disconnecting the VPN, `/etc/resolver/japfacomfeed.co.id` is removed (2.5).
