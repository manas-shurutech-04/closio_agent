# Agent Rules

Every rule closio-agent follows when it runs, in one place. **Every rule is strict.** Each one links to the decision that explains why, and says where it's applied today.

- **Git rules (G1–G4):** how the agent uses git.
- **Behaviour rules (A1–A19):** everything else.
- **`AGENTS.md` column:** the rules the AI must follow in every session are also written in [`AGENTS.md`](../AGENTS.md), which Claude Code and Codex read at the start of every session ([D45](design-decisions.md#d45)). The number is the rule's number there.
- **Your user memory never overrides these rules** (A8). If one of your memory entries disagrees with a rule, the agent tells you and follows the rule.
- The rules for **building** closio-agent (R1–R18) are a different list, in [build-memory/rules.md](../build-memory/rules.md).

> Status (2026-10-17): the setup commands are built (incl. `flow-setup-repo`, `flow-memory`, `flow-check-card`, `flow-help`), and of the card phases the pick-up and the plan (`flow-start`, `flow-status`); Phases 3–9 aren't yet. "Not built yet" below means the rule is decided and will be applied by that phase.

## Git rules

| # | Rule | Why | `AGENTS.md` | Where it's applied today |
|---|---|---|---|---|
| G1 | Always pull from the base branch set for the repo (`base_branch` in `config/repos/<repo>.yaml`; it can differ per repo). | [D51](design-decisions.md#d51) | — | Built (C2): `scripts/card-branch.sh` pulls the repo's base branch before creating the card's branch (`flow-start`). Phase 7 (rebase) not built yet; `card-branch.sh update` brings the latest base branch into the card's branch before every plan (step 7) |
| G2 | Before every push, rebase the branch onto that base branch, in this order: **stash the changes → rebase → stash pop → then atomic commits**. | [D10](design-decisions.md#d10) | — | Not built yet: Phase 7 |
| G3 | Develop together first, then make atomic commits. Never push everything as one commit. | [D10](design-decisions.md#d10) | — | Not built yet: Phases 3 and 7 |
| G4 | Only **one push** to the remote, after connecting to GitLab. | [D10](design-decisions.md#d10), [D18](design-decisions.md#d18) (tests run before the push, so a failure never needs a second push), [D31](design-decisions.md#d31) (the same push creates the MR) | — | Not built yet: Phase 7 |

## Behaviour rules

| # | Rule | Why | `AGENTS.md` | Where it's applied today |
|---|---|---|---|---|
| A1 | Every step of a card writes a history entry. If a run is paused, its context is saved in files, so it can carry on from there. | [D36](design-decisions.md#d36), [D38](design-decisions.md#d38) | — | Built (C1): `scripts/run.sh` writes `runs/<CARD-KEY>/history.md` (one line per step) and `state.md`; `flow-start` carries on from the last finished step; `flow-status` shows it |
| A2 | Any GitLab step (pull, fetch, push, MR) connects the VPN by itself if it's off. You only type your Mac password and, if asked, finish the SSO login. | [D14](design-decisions.md#d14), [D30](design-decisions.md#d30) | — | Built (F3): `scripts/vpn.sh`, `flow-vpn`, the `flow-connectivity` agent |
| A3 | Never move a card to **Blocked**. That status is for QA only. | [D11](design-decisions.md#d11) | — | Built (C2): `flow-start` moves the card only to In Development. Phases 8 and 9 not built yet |
| A4 | Every command runs in **both Claude Code and Codex**, and **only when you type it**. | [D8](design-decisions.md#d8), [D16](design-decisions.md#d16), [D44](design-decisions.md#d44) | 1 | Built: every command file has `disable-model-invocation: true` (Claude Code) and `agents/openai.yaml` (Codex) |
| A5 | At the start of each phase that needs GitLab or the dev servers (Phases 1–9), a helper agent connects the VPN and checks GitLab. Manual steps (Mac password, SSO login) are fine. `flow-setup-repo` doesn't need it. | [D30](design-decisions.md#d30), [D47](design-decisions.md#d47) (its limits), [D54](design-decisions.md#d54) | — | Built (F3): the `flow-connectivity` agent; `flow-start` calls it in its first step (C2) |
| A6 | Scripts and apps load `.env` files themselves. The AI never reads or prints `.env` values in the chat. *(Adopted for now; to be confirmed.)* | [D34](design-decisions.md#d34) | 3 | `flow-configure-repo` reads only the **names** of variables (from `.env.example`), never what's inside `.env` |
| A7 | Every command loads **your user memory** (`local/memory/`) and acts on it, if it exists. | [D40](design-decisions.md#d40), [D56](design-decisions.md#d56) | 9 | Built (F6b): every command starts with `bash scripts/memory.sh for setup all` (Claude Code runs it by itself when the command loads; in Codex it's the first step). `flow-memory` manages the entries; the AI offers to save your corrections |
| A8 | **Team rules always win over user memory.** On a conflict, the agent says so and follows the team rule. | [D40](design-decisions.md#d40), [D56](design-decisions.md#d56) | 9 | Built (F6b): in every command's memory step, and `flow-memory` warns when a new entry goes against a team rule |
| A9 | Run `nvm use v22` before starting Claude Code or Codex. closio-agent itself, Claude Code and Codex run on **Node 22**. | [D41](design-decisions.md#d41) | 2 | `flow-doctor` checks that Node 22 is active |
| A10 | Always start Claude Code or Codex **in the closio-agent folder**, never inside a code repo. The agent adds the code repos as extra folders. | [D42](design-decisions.md#d42) | 2 | `flow-doctor`, `flow-configure-user`, `flow-configure-repo` and `flow-setup-repo` check it. `flow-setup-repo` adds each repo folder for Claude Code and shows Codex's start command with `--add-dir` ([D54](design-decisions.md#d54)) |
| A11 | Whenever anything fails (a check, a step, a command), tell the user the **exact steps to fix it**. | [D45](design-decisions.md#d45) | 4 | Every check in the scripts prints a fix or tip line |
| A12 | Branch names: **`SCRUM-<number>/<short-description>`**: lowercase words joined by `-` (only a-z and 0-9), **at most 5 words**, the same name in every repo of a card. | [D50](design-decisions.md#d50) | 5 | `scripts/branch-name.sh` makes and checks names; `flow-start` suggests the name with it, the user confirms, and `scripts/card-branch.sh` creates the same branch in every repo (C2) |
| A13 | Each code repo runs on **the Node version it's built for** (`node_version` in `config/repos/<repo>.yaml`, from its Dockerfile). Before running anything in a repo: `nvm use <version>`, and `nvm install <version>` first if it's missing. | [D52](design-decisions.md#d52) | 6 | `flow-setup-repo` switches to that version before running anything in a repo, and installs it with nvm if missing; `flow-doctor` and `flow-configure-repo` warn when it isn't installed |
| A14 | **Cloning a repo is always manual.** The agent never clones; it gives you the `git clone` command. | [D53](design-decisions.md#d53) | 7 | `flow-doctor`, `flow-configure-repo` and `flow-setup-repo` give the clone command when a repo isn't on your Mac |
| A15 | **Ask for folder access first.** Before working in a code repo, check that this session can use its folder. If it can't, stop and ask the user to give access, with the exact way (Claude Code: `/add-dir <folder>` or a new session; Codex: restart with `codex --add-dir <folder>` or approve its request), and go on only after they have. | [D55](design-decisions.md#d55) | 8 | `flow-setup-repo` checks it for every repo it sets up; `flow-start` checks it before creating a branch in a repo (C2) |
| A18 | **A plan is made from the code, with questions first and the user's manual approval before it's saved.** Before planning a card, pull the base branches and read the current code of every repo involved; never plan from the card alone. List every difference between the card and the code (error codes, statuses, messages, fields, anything the card names that isn't in the code), ask the user about them first and wait. Only then draft the plan. Nothing is saved or pushed before the user approves the plan in chat. | [D63](design-decisions.md#d63) | 13 | Built (C2): `flow-start` steps 7–11: the code first, the questions, the draft, the manual approval, then the save; step 7 first brings in the latest base branch (`card-branch.sh update`), and continuing at steps 8–10 goes back to step 7 |
| A17 | **Rules and memory before every step of a card phase.** Every card-phase command, before each of its steps, re-reads the team rules (`AGENTS.md`, this file) and the user-created memory (the entries made with `flow-memory`, in `local/memory/`) for that phase and the repos involved, applies them, and writes in the card's `history.md` which rules and entries it applied. Nothing is skipped. | [D62](design-decisions.md#d62) | 12 | Built (C1, C2): `flow-status` and `flow-start` do it before every step and log it in the card's `history.md`. The later card commands follow |
| A16 | **Error codes, HTTP statuses and messages always come from the code.** Before developing a card, read the ones that already exist in every repo it touches. If the card lists error codes, check each one against the code and point out every difference; use the code's exact errors and messages for the right conditions. Never invent a new one without the user's approval. | [D59](design-decisions.md#d59) | 10 | Built (C2): `flow-start` reads the existing error codes in the code and asks about every difference with the card before the plan. Phase 3 not built yet |
| A19 | **Rulesets are ours; users adjust them only through their memory.** Every card follows `rulesets/story-implementation-workflow.md` (backend repos: all of it; the web app: its common practices until a frontend ruleset exists). The closio-agent builders keep it; no command adds or changes it. A user's memory entry may change one of its points for that user, and the plan names which entry changed which point; these rules always win over both (A8). | [D64](design-decisions.md#d64), [D26](design-decisions.md#d26) | 14 | Built: `bash scripts/configure-repo.sh ruleset <repo>`; `flow-start` reads it in step 7 and names it, with the memory applied, at the top of the plan; `flow-doctor` checks the file is there. Phase 3 (`flow-develop`) not built yet |

## When a rule changes

In the same step:

1. record the decision in [design-decisions.md](design-decisions.md);
2. update this file;
3. update `AGENTS.md` if it's a rule the AI must follow in every session;
4. update the build memory's copy (`build-memory/project-context.md`, sections "Agent Git Rules" and "Agent Behaviour Rules"), which also keeps who asked for it and when.
