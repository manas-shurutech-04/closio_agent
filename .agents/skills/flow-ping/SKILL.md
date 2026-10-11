---
name: flow-ping
description: Checks that the flow commands are installed and loading in this tool. Runs only when the user types /flow-ping (Claude Code) or $flow-ping (Codex).
disable-model-invocation: true
---

# flow-ping

Answers one question: are the flow commands loaded in this tool? It changes nothing and runs no commands.

1. **User memory (rule A7):** if `local/memory/general.md` exists, read it and apply any entry meant for this command. Team rules always win (rule A8). If the file doesn't exist, carry on; that's normal.
2. Reply with exactly these two lines and nothing else:

```
flow commands are loaded in <the tool you are running in: Claude Code or Codex>
You typed: <the text the user typed after the command, or "nothing">
```

The text typed after the command is in the user's message. In Claude Code it may also appear as `ARGUMENTS: …` at the end of these instructions.
