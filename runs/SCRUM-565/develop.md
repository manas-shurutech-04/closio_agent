# SCRUM-565 — development

Plan: plan.md (approved on 2026-10-21) · Ruleset: rulesets/frontend-story-workflow.md · Memory applied: none

## closio-web-v2: done (repo 1 of 1)
New:      none
Changed:  src/views/incentive/components/ChannelBox.vue (CSS only, `<style scoped>`)
          - Added `@media (max-width: 768px)` block:
            - `.channel-header { flex-direction: column; align-items: stretch; }`
            - `.channel-dropdown { max-width: none; }` (full width on small screens)
            - `.channel-header :deep(.base-button) { width: 100%; }` (+ Tipe Salesman full width below)
            - `.icon-btn { align-self: flex-end; }` (trash icon kept accessible, right-aligned)
          - No template, script, or prop change.
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
(pending the user's review)
