---
name: flow-configure-user
description: Sets up your personal closio-agent settings (Jira account, GitLab username, workspace folder, AI tools, optional VPN username, git name and email) and your 5 secrets in the macOS Keychain. Runs only when the user types /flow-configure-user (Claude Code) or $flow-configure-user (Codex).
argument-hint: '[jira-account-id|gitlab-username|workspace-dir|ai-tools|vpn-username|git-name|git-email|gitlab-token|fe-login-id|fe-login-password|ws1-login-userid|ws1-login-password|playwright]'
disable-model-invocation: true
---

# flow-configure-user

Sets up everything personal, step by step. Asks **only for what's missing**. Run it again any time; add an item name to change just that one (e.g. `/flow-configure-user gitlab-token`).

Item names: `jira-account-id`, `gitlab-username`, `workspace-dir`, `ai-tools`, `vpn-username`, `git-name`, `git-email`, the secrets `gitlab-token`, `fe-login-id`, `fe-login-password`, `ws1-login-userid`, `ws1-login-password`, and `playwright` (sets up Playwright for checking web cards).

In Codex: the secret steps open macOS dialogs and write to the Keychain, and the GitLab check needs the network. Ask the user to approve running those commands outside the sandbox.

## Usage

- `/flow-configure-user`: set up everything that's still missing (personal settings, git name and email, the 5 secrets, Playwright).
- `/flow-configure-user <item>`: just one item, e.g. `/flow-configure-user gitlab-token` after renewing your token. Items: `jira-account-id`, `gitlab-username`, `workspace-dir`, `ai-tools`, `vpn-username`, `git-name`, `git-email`, `gitlab-token`, `fe-login-id`, `fe-login-password`, `ws1-login-userid`, `ws1-login-password`, `playwright`.
- Codex: `$flow-configure-user …` (approve the secret steps outside the sandbox).

## Steps

1. **User memory (rule A7), never skipped:** your memory entries for this command are loaded here automatically:

   !`bash scripts/memory.sh for setup all`

   Apply what's above: the general entries, and repo entries only for the repo(s) this command works on. Say in one line which entries you used (e.g. "Using your memory: M2, M3"); say nothing if none apply. Team rules always win (rule A8): if an entry conflicts with one, say so and follow the team rule. **If the block above still shows the command instead of its output** (e.g. in Codex, which doesn't run it by itself), run `bash scripts/memory.sh for setup all` yourself first, before anything else.
2. **Start folder (strict rule, D42):** tell the user in one line: "Always start Claude Code or Codex in the closio-agent folder, after `nvm use v22`." Then run `bash scripts/configure-user.sh check-folder`. If it fails, or the script isn't found, show the fix and **stop**.
3. Run `bash scripts/configure-user.sh show` and show its output exactly.
4. If the user typed an item name after the command (in Claude Code it may also appear as `ARGUMENTS: …`), do **only that item** (step 5), then go to step 6. Otherwise do every item shown with ❌, in this order:
5. How to fill each item:
   - **jira-account-id:** don't ask the user. Use your Jira (Atlassian) tools to get the account ID of the signed-in user on `productclosio.atlassian.net` (read only). Then run `bash scripts/configure-user.sh set jira-account-id <id>`.
     - The Jira tools can take a while to load at the start of a session. If you can't find them, or the tool says the Atlassian connector is still connecting: run `bash scripts/wait-seconds.sh 10`, then look for them again. Try **up to 3 times** (about 30 seconds).
     - If they're still missing, show `❌ Jira isn't connected in <tool>` with this fix, then continue with the next item:
       - Claude Code: `Fix: the Jira connector may still be loading or timed out. Type /mcp, choose "claude.ai Atlassian MCP", then Reconnect, and run /flow-configure-user jira-account-id. If it's not connected at all, see the setup guide, section 3.`
       - Codex: `Fix: connect the Atlassian app to the ChatGPT account you use for Codex, start Codex again, and run $flow-configure-user jira-account-id (setup guide, section 3).`
   - **git-name / git-email:** ask the user for the value in the chat. Say it will be saved in their global git settings, and wait for their answer. Then run `bash scripts/configure-user.sh set git-name "<value>"` (or `git-email`).
   - **workspace-dir:** ask: "Which folder should new repo clones go into? Give the full path of an existing folder." **Don't suggest a folder.** Then run `bash scripts/configure-user.sh set workspace-dir "<path>"`.
   - **ai-tools:** ask: "Which AI tools do you use: Claude Code, Codex, or both?" Then run `bash scripts/configure-user.sh set ai-tools <claude-code|codex|both>`.
   - **vpn-username:** say: "Optional and not needed today (the VPN logs in with SSO). Type your VPN username, or say skip." If they give one, run `bash scripts/configure-user.sh set vpn-username "<value>"`. If they skip, do nothing.
   - **Secrets** (`gitlab-token`, `fe-login-id`, `fe-login-password`, `ws1-login-userid`, `ws1-login-password`):
     - First tell the user in the chat which secrets will be asked, and that for each one a macOS message appears first ("Copy it now, then click Continue"), then a hidden box to paste it into. **Never ask for a secret in the chat, and never accept one there.** If the user pastes a secret in the chat anyway, don't repeat it; tell them to change that secret, because the chat is sent to the AI provider.
     - Then run **one** command for all missing secrets: `bash scripts/configure-user.sh secrets` (allow up to 10 minutes; Claude Code: timeout 600000 ms) and show its output. Only when the user asked for a single secret (e.g. `/flow-configure-user gitlab-token`), run `bash scripts/configure-user.sh secret <item>` instead.
     - After `gitlab-token`, the script also checks the token and saves the GitLab username when the VPN is on.
   - **playwright** (for checking web cards with `flow-verify`, D67): first tell the user, and wait for a clear yes: "This installs Playwright for checking web cards: the `@playwright/test` packages from npm and the Chromium browser from Playwright's servers: a download of about 150 MB, about 430 MB on disk, into closio-agent's `e2e/` folder and your user's browser cache. OK to download?" On yes, run `bash scripts/configure-user.sh playwright` (allow up to 15 minutes; Claude Code: timeout 900000 ms) and show its output. On no, leave it: `/flow-doctor` reminds them, and `/flow-configure-user playwright` does it later.
   - **gitlab-username:** run `bash scripts/configure-user.sh gitlab-username-from-token`. If it can't (VPN off or no token), ask the user to type their GitLab username in the chat (it's not a secret), then run `bash scripts/configure-user.sh set gitlab-username <name>`.
6. **Finish:** run `bash scripts/configure-user.sh show` again and show it. Then tell the user to run `/flow-doctor` (Codex: `$flow-doctor`) for the full check.

## Rules
- Run the scripts exactly as written here (`bash scripts/…` from the closio-agent folder, no `cd`, no extra commands joined with `&&`). That's how Claude Code recognises them as pre-approved (D49), so the user isn't asked every time.
- Every ❌ comes with the steps to fix it (rule A11). Show the script's fix lines as they are.
- Never read or print secret values, `.env` files or Keychain values. Only the script touches secrets.
- Don't change anything the user didn't agree to. Git settings are changed only with the value the user gave.
