# SCRUM-565 — development

Plan: plan.md (approved on 2026-10-21) · Ruleset: rulesets/frontend-story-workflow.md · Memory applied: none

## closio-web-v2: done (repo 1 of 1)
New:      none
Changed:  src/views/incentive/components/ChannelBox.vue (CSS only, `<style scoped>`)
          - `.channel-header`: added `flex-wrap: wrap` (row wraps instead of squeezing).
          - `.channel-dropdown-wrap`: `flex: 1` -> `flex: 1 1 200px`, `min-width: 0` -> `min-width: 200px`
            (the dropdown can never collapse; container-driven, works above 768px too).
          - Added `@media (max-width: 768px)` block for a clean full-width mobile stack:
            - `.channel-header { flex-direction: column; align-items: stretch; }`
            - `.channel-dropdown { max-width: none; }`
            - `.channel-header :deep(.base-button) { width: 100%; }`
            - `.icon-btn { align-self: flex-end; }`
          - No template, script, or prop change.
          - NOTE: first attempt used only the 768px stack; it still broke at 786px (above the breakpoint,
            because the sidebar eats width). Switched to the container-driven flex-wrap + min-width (decision 8).
Tests:    Full suite 4074 passed, 1 failed (pre-existing flaky, see below). ChannelBox.test.ts: 11 passed. No new unit test — CSS media-query behavior is not assertable in jsdom; verified visually in flow-verify.
Checks:   closio-web-v2 has no check commands (check_commands: none). · lint: n/a (no lint command)
Not in the plan: none
Reused and new: CSS-only change; no functions/helpers/constants created (searched src/views/incentive/components — none needed). Reused the existing `@media (max-width: 768px)` breakpoint convention from the incentive pages.
Queries:  none
Next:     your review

### Pre-existing flaky test (unrelated)
- `src/views/roles/__tests__/Roles.test.ts > Roles.vue > shows error state when API fails` fails in the full parallel run ("spy called 2 times, expected 1") but passes in isolation (16/16). Roles module, unrelated to this card (incentive). Not touched — out of scope.

## Migrations and seeders run
none

## Review
- Review iteration 1: user tested at 786px (DevTools) — still broke, because 786 > 768 and the sidebar eats width. Changed approach to container-driven flex-wrap + `min-width: 200px` on the dropdown wrap so it can't collapse at any width; kept the ≤768px column stack (decision 8). ChannelBox (11) + SlabConfigForm (14) tests pass.
- Approved by the user on 2026-10-21
