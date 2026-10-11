# Rules for AI tools in closio-agent

Claude Code and Codex both read this file at the start of every session in this folder (D45).

1. Flow commands run only when the user types them (`/flow-…` or `$flow-…`).
   Don't do a command's steps or run its scripts on your own.
   If the user asks for something a command does (e.g. "check my setup"),
   tell them which command to type (e.g. `/flow-doctor` or `$flow-doctor`) and stop.
   Only exception: the user clearly asks you to run or test a specific script.
2. Sessions start in this folder, after `nvm use v22`.
3. Never read or print secrets, `.env` values or Keychain values.
4. When anything fails (a check, a step, a command), always tell the user the exact steps to fix it (rule A11).
