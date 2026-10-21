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
| 8 | 2026-10-21 15:40 | review 10 | Fix still broke at 786px (above the 768 breakpoint). Change approach? | Switch from a pure 768px stack to a container-driven fix: .channel-header flex-wrap:wrap and .channel-dropdown-wrap flex:1 1 200px/min-width:200px so the dropdown can't collapse and the row wraps at any width; keep the <=768px column stack for clean mobile | you |
| 9 | 2026-10-21 15:41 | review 10 | Review approved? | Yes, approved after the container-driven fix | you |
| 10 | 2026-10-21 15:56 | verify 1 | Full or quick check? | B quick check | you |
| 11 | 2026-10-21 16:16 | push 7 | Approve the atomic commit? | Yes: one commit 'SCRUM-565: Make the channel header responsive on small screens' (ChannelBox.vue) | you |
| 12 | 2026-10-21 16:18 | push 9 | Push and create the MR? Reviewers/labels? | Yes, push; no reviewers, no labels | you |
| 13 | 2026-10-21 16:41 | finish 3 | Deployed on dev? | Yes, deployed on dev (closio-web-v2) | you |
| 14 | 2026-10-21 17:03 | finish 4 | Re-run the AC checks on dev? | No — skip the dev re-check; the ACs already passed on dev in verify Run 2 (all 3 ACs) | you |
| 15 | 2026-10-21 17:04 | finish 5 | Anything special for the deployment doc (order, flag, manual step)? | None | you |
