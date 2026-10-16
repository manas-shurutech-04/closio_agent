---
name: flow-vpn
description: Connects, checks or disconnects the Japfa VPN (connect, status, disconnect). Runs only when the user types /flow-vpn (Claude Code) or $flow-vpn (Codex).
disable-model-invocation: true
---

# flow-vpn

Connects, checks or disconnects the Japfa VPN. The VPN stays on until the user disconnects it.

## Usage

- `/flow-vpn connect`: connect (one macOS password dialog, then the SSO login in your browser if it asks). Does nothing if GitLab already answers.
- `/flow-vpn status`: on (and through which client), off, or a problem with its fix. Only reads.
- `/flow-vpn disconnect`: disconnect (one password dialog) and remove the VPN DNS file.
- Codex: `$flow-vpn connect | status | disconnect` (approve running it outside the sandbox).

## Steps

1. **User memory (rule A7), never skipped:** your memory entries for this command are loaded here automatically:

   !`bash scripts/memory.sh for setup all`

   Apply what's above: the general entries, and repo entries only for the repo(s) this command works on. Say in one line which entries you used (e.g. "Using your memory: M2, M3"); say nothing if none apply. Team rules always win (rule A8): if an entry conflicts with one, say so and follow the team rule. **If the block above still shows the command instead of its output** (e.g. in Codex, which doesn't run it by itself), run `bash scripts/memory.sh for setup all` yourself first, before anything else.
2. The word typed after the command is the action: `connect`, `status` or `disconnect`. In Claude Code it may also appear as `ARGUMENTS: …` at the end of these instructions. If it's missing or something else, show `Usage: /flow-vpn connect | status | disconnect` (Codex: `$flow-vpn …`) and stop.
3. From the folder this session started in, run: `bash scripts/vpn.sh <action>`
   - For `connect` and `disconnect`, first tell the user in one line: "A macOS password dialog will appear. Type your Mac password there (for connect, then finish the SSO login in your browser if it asks)."
   - Allow up to 5 minutes (Claude Code: timeout 300000 ms).
   - In Codex, ask the user to approve running it outside the sandbox: it needs admin rights and the network.
4. If `scripts/vpn.sh` isn't found, this session wasn't started in the closio-agent folder. Tell the user: "Quit, open a terminal in the closio-agent folder, run `nvm use v22`, then start Claude Code or Codex again." Stop there.
5. Show the script's output exactly as printed. Every ❌ already includes the steps to fix it (rule A11).

Rules:
- Run the script exactly as written here (`bash scripts/…` from the closio-agent folder, no `cd`, nothing joined with `&&`). That's how Claude Code recognises it as pre-approved (D49).
- Run only that command. Don't fix anything yourself.
- Never read or print secrets, `.env` files or Keychain values.
