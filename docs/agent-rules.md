# Agent Rules

Every rule closio-agent follows when it runs, in one place. **Every rule is strict.** Each one links to the decision that explains why, and says where it's applied today.

- **Git rules (G1–G4):** how the agent uses git.
- **Behaviour rules (A1–A14):** everything else.
- **`AGENTS.md` column:** the rules the AI must follow in every session are also written in [`AGENTS.md`](../AGENTS.md), which Claude Code and Codex read at the start of every session ([D45](design-decisions.md#d45)). The number is the rule's number there.
- **Your user memory never overrides these rules** (A8). If one of your memory entries disagrees with a rule, the agent tells you and follows the rule.
- The rules for **building** closio-agent (R1–R16) are a different list, in [build-memory/rules.md](../build-memory/rules.md).

> Status (2026-10-15): the setup commands are built; the card phases (1–9) aren't yet. "Not built yet" below means the rule is decided and will be applied by that phase.

## Git rules

| # | Rule | Why | `AGENTS.md` | Where it's applied today |
|---|---|---|---|---|
| G1 | Always pull from the base branch set for the repo (`base_branch` in `config/repos/<repo>.yaml`; it can differ per repo). | [D51](design-decisions.md#d51) | — | Not built yet: Phase 1 (new branches) and Phase 7 (rebase) |
| G2 | Before every push, rebase the branch onto that base branch, in this order: **stash the changes → rebase → stash pop → then atomic commits**. | [D10](design-decisions.md#d10) | — | Not built yet: Phase 7 |
| G3 | Develop together first, then make atomic commits. Never push everything as one commit. | [D10](design-decisions.md#d10) | — | Not built yet: Phases 3 and 7 |
| G4 | Only **one push** to the remote, after connecting to GitLab. | [D10](design-decisions.md#d10), [D18](design-decisions.md#d18) (tests run before the push, so a failure never needs a second push), [D31](design-decisions.md#d31) (the same push creates the MR) | — | Not built yet: Phase 7 |

## Behaviour rules

| # | Rule | Why | `AGENTS.md` | Where it's applied today |
|---|---|---|---|---|
| A1 | Every step of a card writes a history entry. If a run is paused, its context is saved in files, so it can carry on from there. | [D36](design-decisions.md#d36), [D38](design-decisions.md#d38) | — | Not built yet: the card's run folder `runs/<CARD-KEY>/` (Phases 1–9) |
| A2 | Any GitLab step (pull, fetch, push, MR) connects the VPN by itself if it's off. You only type your Mac password and, if asked, finish the SSO login. | [D14](design-decisions.md#d14), [D30](design-decisions.md#d30) | — | Built (F3): `scripts/vpn.sh`, `flow-vpn`, the `flow-connectivity` agent |
| A3 | Never move a card to **Blocked**. That status is for QA only. | [D11](design-decisions.md#d11) | — | Not built yet: the Jira moves in Phases 1, 8 and 9 |
| A4 | Every command runs in **both Claude Code and Codex**, and **only when you type it**. | [D8](design-decisions.md#d8), [D16](design-decisions.md#d16), [D44](design-decisions.md#d44) | 1 | Built: every command file has `disable-model-invocation: true` (Claude Code) and `agents/openai.yaml` (Codex) |
| A5 | At the start of each phase that needs GitLab or the dev servers (Phases 1–9 and `flow-setup-repo`), a helper agent connects the VPN and checks GitLab. Manual steps (Mac password, SSO login) are fine. | [D30](design-decisions.md#d30), [D47](design-decisions.md#d47) (its limits) | — | Built (F3): the `flow-connectivity` agent. The phases will call it once they're built |
| A6 | Scripts and apps load `.env` files themselves. The AI never reads or prints `.env` values in the chat. *(Adopted for now; to be confirmed.)* | [D34](design-decisions.md#d34) | 3 | `flow-configure-repo` reads only the **names** of variables (from `.env.example`), never what's inside `.env` |
| A7 | Every command loads **your user memory** (`local/memory/`) and acts on it, if it exists. | [D40](design-decisions.md#d40) | — | Partly built: every command reads `local/memory/general.md` if it exists. The memory command and per-repo memory come with F6b |
| A8 | **Team rules always win over user memory.** On a conflict, the agent says so and follows the team rule. | [D40](design-decisions.md#d40) | — | Written into every command file; the full memory feature comes with F6b |
| A9 | Run `nvm use v22` before starting Claude Code or Codex. closio-agent itself, Claude Code and Codex run on **Node 22**. | [D41](design-decisions.md#d41) | 2 | `flow-doctor` checks that Node 22 is active |
| A10 | Always start Claude Code or Codex **in the closio-agent folder**, never inside a code repo. The agent adds the code repos as extra folders. | [D42](design-decisions.md#d42) | 2 | `flow-doctor`, `flow-configure-user` and `flow-configure-repo` check it. Adding repos as extra folders comes with F6 |
| A11 | Whenever anything fails (a check, a step, a command), tell the user the **exact steps to fix it**. | [D45](design-decisions.md#d45) | 4 | Every check in the scripts prints a fix or tip line |
| A12 | Branch names: **`SCRUM-<number>/<short-description>`**: lowercase words joined by `-` (only a-z and 0-9), **at most 5 words**, the same name in every repo of a card. | [D50](design-decisions.md#d50) | 5 | `scripts/branch-name.sh` makes and checks names. Phase 1 will use it |
| A13 | Each code repo runs on **the Node version it's built for** (`node_version` in `config/repos/<repo>.yaml`, from its Dockerfile). Before running anything in a repo: `nvm use <version>`, and `nvm install <version>` first if it's missing. | [D52](design-decisions.md#d52) | 6 | `flow-doctor` and `flow-configure-repo` warn when a repo's version isn't installed. Switching before each run comes with F6 |
| A14 | **Cloning a repo is always manual.** The agent never clones; it gives you the `git clone` command. | [D53](design-decisions.md#d53) | 7 | `flow-doctor` and `flow-configure-repo` give the clone command when a repo isn't on your Mac |

## When a rule changes

In the same step:

1. record the decision in [design-decisions.md](design-decisions.md);
2. update this file;
3. update `AGENTS.md` if it's a rule the AI must follow in every session;
4. update the build memory's copy (`build-memory/project-context.md`, sections "Agent Git Rules" and "Agent Behaviour Rules"), which also keeps who asked for it and when.
