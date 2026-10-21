# SCRUM-562 — decisions

Every decision made on this card, in order and in full: the answers, the approvals and refusals at a stop, the memory entries that answered. The other files of this folder only point here ("decision 3").

| No. | When | Step | Question | Decided | Who / why |
|---|---|---|---|---|---|
| 1 | 2026-10-21 14:31 | pick-up 2 | Card assigned to Jayesh Pratap, not the user — go on? | Yes, pick it up and reassign to the user | you |
| 2 | 2026-10-21 14:33 | pick-up 2 | Screenshot-only Bug card (no Context/ACs/QA) — how to proceed? | Proceed and keep the card's gaps (allowed for a Bug); user confirms intent in chat | you |
| 3 | 2026-10-21 14:33 | pick-up 2 | Expected fix for valid_to error shown on valid_from field? | Conditional: during planning, check whether the frontend maps each API field-error to its matching field and whether a valid_to-only validation error is reproducible on dev. Fix only if both hold; otherwise add a comment on the card and move to the next card — no code change | you |
| 4 | 2026-10-21 14:38 | pick-up 4 | Which repos does the card need? | closio-web-v2 only (frontend error-display bug; API already returns the correct valid_to error) | you |
| 5 | 2026-10-21 14:41 | pick-up 5 | Branch name? | SCRUM-562/valid-to-error-wrong-field (user's bug/scrum-562 prefix rejected by strict rule A12; team rule wins) | you |
| 6 | 2026-10-21 14:52 | plan 8 | Fix approach: error-message routing vs date-picking validation? | Fix at date-picking: block the invalid same-month case client-side (disable Save + inline error), not re-route the server error message | you |
| 7 | 2026-10-21 14:52 | plan 8 | Enforce to <= from on the client without checking backend? | Confirm the backend rule first (is same-month truly invalid, or a backend bug) before changing the client rule | you |
| 8 | 2026-10-21 14:52 | plan 8 | Which field shows the inline error when to <= from? | The field the user just changed (from or to), not always Berlaku sampai | you |
| 9 | 2026-10-21 15:05 | plan 8 | Outcome after backend confirmation? | Not reproducible on current development: frontend already gates Save (to >= from, same rule as backend) and always serializes a valid YYYY-MM valid_to; the reported error was forced via a mock API. No code change. Posted explanatory comment on the card (QA used a mock API). | you |
