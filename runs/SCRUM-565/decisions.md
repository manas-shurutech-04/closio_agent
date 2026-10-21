# SCRUM-565 — decisions

Every decision made on this card, in order and in full: the answers, the approvals and refusals at a stop, the memory entries that answered. The other files of this folder only point here ("decision 3").

| No. | When | Step | Question | Decided | Who / why |
|---|---|---|---|---|---|
| 1 | 2026-10-21 15:19 | pick-up 2 | Screenshot-only Bug card (no Context/ACs/QA) — how to proceed? | Proceed and keep the card's gaps (allowed for a Bug); user confirmed intent in chat | you |
| 2 | 2026-10-21 15:19 | pick-up 2 | Expected behavior for the channel dropdown / button overlap on small resolution? | On small/mobile widths the channel dropdown keeps a usable width (options on one line, not one char per line) and the + Tipe Salesman button does not overlap the dropdown; the Channel row lays out responsively | you |
| 3 | 2026-10-21 15:20 | pick-up 4 | Which repos does the card need? | closio-web-v2 only (pure CSS/layout bug in the web app) | you |
| 4 | 2026-10-21 15:23 | pick-up 5 | Branch name? | SCRUM-565/fix-channel-dropdown-overlap | you |
| 5 | 2026-10-21 15:26 | plan 8 | Where to fix the layout? | In the shared ChannelBox.vue <style scoped> (covers both AgeingConfigForm and SlabConfigForm) | you |
| 6 | 2026-10-21 15:26 | plan 8 | Responsive breakpoint and behavior? | @media (max-width: 768px) stacks .channel-header vertically: title, then full-width dropdown, then full-width + Tipe Salesman button; trash icon kept accessible. CSS only, no template/logic change | you |
| 7 | 2026-10-21 15:29 | plan 10 | Plan approved? | Yes, approved as-is | you |
