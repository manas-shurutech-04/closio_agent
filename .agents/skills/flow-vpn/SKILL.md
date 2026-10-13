---
name: flow-vpn
description: Connects, checks or disconnects the Japfa VPN (connect, status, disconnect). Runs only when the user types /flow-vpn (Claude Code) or $flow-vpn (Codex).
disable-model-invocation: true
---

# flow-vpn

Connects, checks or disconnects the Japfa VPN. The VPN stays on until the user disconnects it.

1. **User memory (rule A7):** if `local/memory/general.md` exists, read it and apply any entry meant for this command. Team rules always win (rule A8). If the file doesn't exist, carry on; that's normal.
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
