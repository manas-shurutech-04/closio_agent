# Rules (non-negotiable)

| # | Rule | How it is applied |
|---|------|-------------------|
| R1 | **No hallucination.** | Stick strictly to user instructions and verified facts. Options and suggestions are welcome but must be clearly labelled as suggestions, never mixed into what is implemented or presented as fact. If unsure, ask. |
| R2 | **Docs always up to date.** | Every step that changes anything updates the relevant docs in the same step. A step is not done until its docs are updated. |
| R3 | **Draft before implementing.** | Before finalising anything, present a draft of what will be implemented. Implement only after the user explicitly approves. |
| R4 | **No filler or progress messages.** | Don't spend tokens narrating progress ("now doing X…"). Output only what matters: drafts, questions, results. |
| R5 | **Build memory is separate from the agent's own memory.** | `build-memory/` is used at every step of building. The agent's memory while it runs is designed and stored separately. |
| R6 | **Ask when confused.** | Ask questions wherever a requirement is unclear, and reach common ground before proceeding. |
| R7 | **Advise proactively.** | The user is new to building AI agents, so suggest better approaches and best practices wherever they apply (labelled as suggestions, per R1). |
| R8 | **Always read the core files.** | At every step, always read `build-memory/README.md` and `build-memory/rules.md`. |
| R9 | **Read the other files only when needed.** | Read the other build-memory files only when the step needs them, so the token cost stays low as the files grow. |
| R10 | **Update after every step.** | After each step, update the build-memory files the step touched and add an entry to `history.md`. |
| R11 | **Record each decision in full only once.** | The full record (reasons and rejected options) lives in the team design-decisions doc. `decisions.md` holds one line per decision plus a link to that record. |
| R12 | **Keep language simple.** (user, 2026-10-10) | In every output and doc: short sentences, plain words, no jargon unless needed (and explain it when used). Don't overcomplicate. |
| R13 | **Use relevant names.** (user, 2026-10-10) | Every name (commands, files, folders, tests) must say what the thing does. No placeholder names such as "hello". Commands don't contain "closio"; they start with `flow-` (D43). |
| R14 | **Node v22 for the whole project.** (user, 2026-10-10) | Always `nvm use v22` before starting Claude Code (or Codex) for this project, and before any node/npm/script command run while building or testing it. The code repos use Node 22 too (their Docker images are `node:22-alpine`). Same as agent rule A9 (D41). |
