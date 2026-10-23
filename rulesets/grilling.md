# Grilling: how decisions are asked and taken during a card

> **closio-agent's way of asking for and taking decisions while a card is worked on** ([D76](../docs/design-decisions.md#d76), rule A26, `AGENTS.md` rule 22).
>
> - **Who changes it:** the closio-agent builders, in this folder. No command adds or changes it.
> - **Your user memory can't soften it** (no "fewer rounds", no "don't grill small changes"): it's a team rule, and team rules win (A8). Memory can still answer a repeat question, as the card commands already allow (it says which entry it used).
> - **The decisions:** recorded in full in the card's `decisions.md` (rule A27), with one-line pointers in its other files (section 6).
> - **Where it came from:** the `grilling` skill of Matt Pocock's skills ([github.com/mattpocock/skills](https://github.com/mattpocock/skills), `skills/productivity/grilling`), MIT licence (the text is at the end of this file), adapted on 2026-10-19 to closio-agent's rules: one typed command (`flow-grill`) instead of a skill that starts by itself, facts shown as found instead of asked, safety stops kept, decisions recorded in the card's `decisions.md`, plain words.

---

## When it applies

- **Every question a card command asks you:** `flow-start`, `flow-develop`, `flow-verify`, `flow-ac-check`, `flow-push`, `flow-finish`. (`flow-status` only reads and asks nothing.)
- **Every prompt you give while a card command runs** that changes the card's plan, code, tests, data, Jira or GitLab (e.g. "also return the partner name in the list").
- **Not grilled:** short answers and approvals ("yes", "go on", an answer to the agent's own question), and questions you ask the agent. They go straight through.
- **`/flow-grill`:** the same way, when you ask for it, on a plan, an idea or a card.
- **Not for setup commands:** they rarely need decisions.

## 1. Facts first

Before asking anything, look up everything that can be found: the card, its folder (`runs/<KEY>/`: `card.md`, `plan.md`, `develop.md`, `verify.md`, `ship.md`), the code of every repo the card touches, the repo files in `config/repos/`, the rules and the ruleset. **Never ask the user something the code or the files answer.** Show what was found as short "Found" lines, each with where it was found, so the user can check it:

```
Found
- The partner name is in the partners table; the closest service already joins it (src/services/…/xService.js).
- Tests to update: this API's controller and service tests (test/unit/…).
```

## 2. Rounds of questions

Ask only the **real decisions**: what the code and the files can't settle (a choice between ways, something the card doesn't say, a difference between the card and the code).

- Number them (Q1, Q2 …), each with a short title, what it's about in one or two lines, and a **recommended answer**, worded so that **"yes" accepts it**.
- One round = every question that can be answered now. A question that depends on another answer waits for the next round.
- The user may answer "yes to all", or by number ("Q2: no, …").

```
Round 1
Q1. Partner name in the WS1 response: optional (can be empty)?
    Recommended: yes, like the other optional fields of this response.
Q2. …
Reply "yes to all", or answer by number.
```

## 3. Follow-ups until nothing is open

After each round, work out what the answers opened up and ask only that in the next round. Nothing is assumed silently: a branch nobody decided is a question. Stop when nothing is open.

## 4. The end: what was agreed, then the user's confirmation

Sum up in a few lines what was agreed (each decision with its answer), and wait for the user to confirm. Nothing is changed before that (no code, file, branch, Jira or GitLab change).

**At planning, the draft plan is this summary** ([D90](../docs/design-decisions.md#d90)): in `flow-start`, the answers of step 8 are listed under `## Decided before planning` in the draft plan, and the user's approval of the plan is the confirmation. There's no separate summary round there; nothing is saved before the approval anyway.

## 5. Safety stops stay plain yes/no

Grilling settles the decisions; it never replaces a safety stop. After the grilling, these are still their own plain yes/no, exactly as each command asks them today: running a migration or seeder (after its review), adding test data or sending calls that write, making the commits and pushing, posting on Jira or GitLab, moving the Jira card, approving the plan.

## 6. Where the decisions are saved

**In full, in one place** (rule A27, [D77](../docs/design-decisions.md#d77)): every agreed answer is recorded the moment it's confirmed, in the card's `runs/<KEY>/decisions.md`, with `bash scripts/run.sh decide <KEY> "<step>" "<question>" "<decided>" "<who / why>"` (who: `you`, `you: recommended`, `memory M2`, or the user's own words where they differ from the recommendation). It prints the decision's number.

**A one-line pointer** where the step already keeps its notes, e.g. `- Partner name in the response: yes, optional (decision 5)`:

| Step | Pointer in |
|---|---|
| Planning (`flow-start`) | `card.md`, under `## Explained at pick-up` and `## Decided before planning` |
| Development (`flow-develop`) | `develop.md`, under `## Decided while grilling` |
| Checks (`flow-verify`, `flow-ac-check`) | `verify.md`, in that run's section, under `### Decided while grilling` |
| Push (`flow-push`) | `ship.md`, under `## Decided while grilling` |
| After the merge (`flow-finish`) | the card's `history.md` (its special instructions go in `deployment.md`, as before) |
| `/flow-grill <CARD-KEY>` | `card.md`, under `## Decided while grilling` |

The safety stops' approvals and refusals are recorded the same way. Then log the step as usual (`bash scripts/run.sh log …`).

## 7. The team rules on top

- Plain words on screen: no decision or rule codes (rule A25).
- Never read or print keys, passwords, sessions or `.env` values (A6).
- Error codes, statuses, messages and field names come from the code; a new one is a question, never assumed (A16).
- Team rules always win over the user's memory (A8).

---

## Licence (the grilling skill this is adapted from)

```
MIT License

Copyright (c) 2026 Matt Pocock

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
