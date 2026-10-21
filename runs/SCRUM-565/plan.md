# SCRUM-565 — plan

Approved by the user on 2026-10-21

`Ruleset: rulesets/frontend-story-workflow.md · Memory applied: none`

## Summary
On small/mobile widths, the incentive scheme form's "1. Channel" header collapses: the channel dropdown shrinks to a tiny width (its popup wraps each letter onto its own line) and the "+ Tipe Salesman" button overlaps it. Cause: `ChannelBox.vue` `.channel-header` is a single non-wrapping flex row with no responsive handling. Fix: add a `max-width: 768px` media query to the shared component that stacks the header vertically so the dropdown keeps full width and nothing overlaps.

## Acceptance criteria
_(none in the card — derived from the confirmed expected behavior, decision 2)_
- **AC 1 — Dropdown usable on small screens:** at ≤768px, the channel dropdown takes the full available width; its options render on one line each (no one-character-per-line wrapping).
- **AC 2 — No overlap:** at ≤768px, the "+ Tipe Salesman" button does not overlap the channel dropdown.
- **AC 3 — No regression on desktop:** above 768px, the header keeps its current single-row layout.

## Decided before planning
- Fix in the shared `ChannelBox.vue` `<style scoped>`; covers AgeingConfigForm and SlabConfigForm (decision 5).
- `@media (max-width: 768px)` stacks `.channel-header` vertically; CSS only (decision 6).
- Screenshot-only Bug, gaps kept; expected behavior confirmed in chat (decisions 1, 2).

## Changes
### Web — closio-web-v2 (1 file)
1. **`src/views/incentive/components/ChannelBox.vue`** — in `<style scoped>` only, add:
   - `@media (max-width: 768px)` block that sets `.channel-header { flex-direction: column; align-items: stretch; }`
   - the dropdown wrap / `.channel-dropdown` to span full width (remove the 320px cap at this breakpoint so it fills the column)
   - the `.channel-header :deep(.base-button)` ("+ Tipe Salesman") to full width (`width: 100%`), placed below the dropdown by the column flow
   - keep the trash/remove icon accessible (align to the end of the title row / self-align)
   - No template, script, or prop changes.

## AC → Screen mapping
| AC | Screen and element | How |
|----|--------------------|-----|
| AC 1 | ChannelBox `.channel-dropdown` | Full width in the stacked column; popup inherits the wider button width → options on one line |
| AC 2 | ChannelBox `.channel-header` button | Column layout puts the button below the dropdown; `width:100%`, no overlap |
| AC 3 | ChannelBox `.channel-header` (>768px) | Media query scoped to ≤768px; default row layout untouched |

## Reuse
- Reused: the existing `@media (max-width: 768px)` breakpoint convention from the incentive pages (e.g. `CreateAgeingConfig.vue`). No new components, composables, utils, or constants (searched `src/views/incentive/components`, none needed — CSS-only change).

## Error codes and messages
- None (no API or error handling touched).

## Tests
- Vitest: keep/extend the existing `src/views/incentive/__tests__/ChannelBox.test.ts` to assert the component renders the header, dropdown, and button (CSS media-query behavior isn't assertable in jsdom). Coverage gate per the repo (70%, non-blocking).
- Responsive/visual behavior verified in the browser step (`flow-verify`) at a mobile width.

## Out of scope
- `CellDropdown.vue` internals (the popup-width logic is correct once the button has a usable width).
- Other screens/components that aren't the Channel header.
- Any backend or API change.
