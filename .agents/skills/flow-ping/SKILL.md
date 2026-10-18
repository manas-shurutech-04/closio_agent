---
name: flow-ping
description: Checks that the flow commands are installed and loading in this tool. Runs only when the user types /flow-ping (Claude Code) or $flow-ping (Codex).
argument-hint: '[any text]'
disable-model-invocation: true
---

# flow-ping

Answers one question: are the flow commands loaded in this tool? It changes nothing; the only thing it runs is the memory step (step 1).

## Usage

- `/flow-ping`: are the flow commands loaded in this tool?
- `/flow-ping <any text>`: the same; the text is only echoed back, to show that typed text reaches the command.
- Codex: `$flow-ping …`

## Steps

1. **User memory (rule A7), never skipped:** your memory entries for this command are loaded here automatically:

   !`bash scripts/memory.sh for setup all`

   Apply what's above: the general entries, and repo entries only for the repo(s) this command works on. Say in one line which entries you used (e.g. "Using your memory: M2, M3"); say nothing if none apply. Team rules always win (rule A8): if an entry conflicts with one, say so and follow the team rule. **If the block above still shows the command instead of its output** (e.g. in Codex, which doesn't run it by itself), run `bash scripts/memory.sh for setup all` yourself first, before anything else.
2. Reply with exactly these two lines (after the one memory line from step 1, if any entry applies) and nothing else:

```
flow commands are loaded in <the tool you are running in: Claude Code or Codex>
You typed: <the text the user typed after the command, or "nothing">
```

The text typed after the command is in the user's message. In Claude Code it may also appear as `ARGUMENTS: …` at the end of these instructions.
