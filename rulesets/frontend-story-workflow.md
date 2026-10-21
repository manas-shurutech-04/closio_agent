# Frontend Story Workflow

> **closio-agent's ruleset for every web-app card** (`type: FE` in `config/repos/`, today `closio-web-v2`; [D80](../docs/design-decisions.md#d80), rule A19). Backend repos follow [story-implementation-workflow.md](story-implementation-workflow.md).
>
> - **Who changes it:** the closio-agent builders, in this folder. No command adds or changes it.
> - **Your own changes go in your user memory** (`flow-memory`): an entry may change a point of this ruleset for you, and the plan names which entry changed which point. The agent rules (`AGENTS.md`, [docs/agent-rules.md](../docs/agent-rules.md)) always win over both.
> - **Where it came from:** the web app's `development` branch (as fetched on 2026-10-18, newest commit 2026-10-16), read on 2026-10-19: its code, its tests and the four Overdue Date screen cards (SCRUM-522 to SCRUM-525). **Every rule here describes what the code already does.** Where the code is mixed, new code follows the newest screens of its module (for incentive: the Overdue Date screens), with two exceptions: messages always through `useAppToast`, dates always through `formatDate` (user, 2026-10-19). Existing code isn't moved unless the card asks.
> - Works the same in Claude Code and Codex. The grilling way ([grilling.md](grilling.md)) and the review checklist ([code-review.md](code-review.md)) apply too.

---

## Overview

| Step | What | closio-agent command |
|------|------|----------------------|
| 1. Read the card | The screens, the ACs, the APIs the screens call, the error codes | `flow-start` (step 2) |
| 2. Explore | Answer four questions about the web app | `flow-start` (step 7) |
| 3. Targeted file reads | Read the reference screen set and what the card touches | `flow-start` (step 7) |
| 4. Plan | List every file, map the ACs, get approval | `flow-start` (steps 8–10) |
| 5. Implement | The API functions, types, utils, components, pages, routes | `flow-develop` |
| 6. Write tests | Vitest tests in the repo | `flow-develop` |
| 7. Run tests | `bash scripts/repo-run.sh closio-web-v2 test` | `flow-develop` (`flow-verify` runs them again) |
| 8. Browser checks | Playwright, outside the repo | `flow-verify`, `flow-ac-check` |
| 9. Verify and ship | Read the edited files, the MR, the review | `flow-verify`, `flow-push`, `flow-review` |

---

## Step 1 — Read the card

`flow-start` reads the card and checks it against the card template ([D58](../docs/design-decisions.md#d58)). A web card written to the template since [D82](../docs/design-decisions.md#d82) has `### Screens in Scope` (screen and route), `### Screen Changes` (Element | Current | New per screen), every response the screen can get with the field that shows each error, and the APIs in its Dev notes; read those first. For a web card, note:
- **The screens**: list, detail, create, edit, a dialog; and where each sits in the menu (its menu path, e.g. Manajemen Insentif › Tipe Insentif).
- **The APIs each screen calls**: method, WS1 path, the request and the response fields. They come from the backend card and the backend code; the backend error codes, statuses and messages too (rule A16). The web app never invents an error code.
- **The copy**: the Indonesian labels, buttons and messages the card gives. Where the card gives none, the screen uses the module's existing copy (see Step 5, Wording).
- **Out of scope** items.

---

## Step 2 — Explore

| Question | What it discovers |
|---|---|
| **A — Where does it go?** | The module folder under `src/views/<module>/`, its `routes.ts`, the menu entry in `src/components/AppSidebar.vue` |
| **B — What's the closest screen?** | The page, its form component, its utils and its tests to copy, file by file |
| **C — What does the module already have?** | Its types, API functions in `src/api/<module>.ts`, utils, constants, components |
| **D — What's shared?** | The shared components, composables, utils and constants to reuse (Step 5) |

---

## Step 3 — Targeted file reads

**The reference screen set** (the incentive Overdue Date screens, the newest full set):
1. `src/views/incentive/IncentiveSchemaList.vue`: a list with filters, `BaseDataTable`, `LoadingSpinner`, `MessageCard`, `ConfirmationDialog`
2. `src/views/incentive/OverdueDateConfigDetail.vue`: a detail page: `Breadcrumb`, a back button, the loading, error and content states, an `AbortController`
3. `src/views/incentive/CreateAgeingConfig.vue` and `EditAgeingConfig.vue`: thin pages that own the API calls, the breadcrumb, the Batal/Simpan buttons, the save and discard `ConfirmationDialog`s, `useUnsavedChangesGuard`, `useAppToast`
4. `src/views/incentive/components/AgeingConfigForm.vue`: the shared form (`v-model:` props, `defineExpose({ isValid, buildPayload })`)
5. `src/views/incentive/utils/ageingConfigValidation.ts`: the checks, the payload and the error mapping as plain functions
6. `src/views/incentive/types/incentive.ts`: the request and response types
7. `src/api/incentive.ts`: the endpoint functions (e.g. `getAgeingDeductionConfigDetail`)
8. `src/views/incentive/routes.ts` and `src/router/index.js`: how routes are declared and registered
9. Their tests: `src/views/incentive/__tests__/OverdueDateConfigDetail.test.ts`, `EditAgeingConfig.test.ts`, `ageingConfigValidation.test.ts`, `src/api/__tests__/incentive.test.ts`

**Shared pieces** (read before writing anything new, rule A21): `src/components/` (Step 5 list), `src/composables/useAppToast.ts`, `useUnsavedChangesGuard.ts`, `useFeatureFlags.ts`, `src/utils/dateFormatter.ts`, `dateHelpers.ts`, `stringFormatter.ts`, `src/utils/permissions/`, `src/constants/`, `src/common-types/`.

**What already exists (rule A21):** for every function, helper, constant, type or component the card needs, search the repo for one that does the same job (by name, by what it does, in `src/utils`, `src/constants`, `src/composables`, `src/components` and the module's `utils/` and `constants/`). Note each one to reuse, and anything close but not the same, to ask the user about.

---

## Step 4 — Plan

### Plan format (the one `flow-start` shows):

```
Ruleset: rulesets/frontend-story-workflow.md · Memory applied: M2 (changes: …) or none

## Summary
## Acceptance criteria
## Decided before planning      (one line each, pointing to the card's decisions.md: "decision 3")

## Changes
### Web — closio-web-v2 (N files)
1. API — src/api/<module>.ts: the functions (method, path, request, response)
2. Types — src/views/<module>/types/<x>.ts
3. Utils — checks, payload, error messages (src/views/<module>/utils/<x>Validation.ts)
4. Components — new or changed (src/views/<module>/components/)
5. Pages — list / detail / create / edit
6. Routes — src/views/<module>/routes.ts (names, paths, meta.permissions, guards)
7. Menu and breadcrumbs — AppSidebar.vue entry (if new), each page's breadcrumb
8. Test ids — <Screen>.testids.ts for a new screen

## AC → Screen mapping
| AC | Screen and element | How |

## Reuse
- Reused: <component / composable / util> from <file> · … · new ones: <name> (searched, none found)

## Error codes and messages   (the backend's, from the code; the screen's fallback copy)
## Tests
## Out of scope
```

---

## Step 5 — Implement

### Order
1. Types, then the API functions
2. Utils (checks, payload, error messages)
3. Components (the shared form first)
4. Pages
5. Routes, the menu entry, the test ids
6. Tests (Step 6), alongside

### Where files go
- Everything for a feature lives in `src/views/<module>/`: the pages at its root, `routes.ts`, and `components/`, `types/`, `utils/`, `constants/`, `__tests__/`. A new module copies that layout.
- API functions in `src/api/<module>.ts`, one file per backend area; their tests in `src/api/__tests__/<module>.test.ts`.
- A new folder only where the module has none yet and the card needs one.

### Components
- `<script setup lang="ts">`; props with `defineProps<{ … }>()` (`withDefaults` for defaults), events with `defineEmits<{ (e: 'name', value: T): void }>()`; `defineExpose` for what a page reads from a form (`isValid`, `buildPayload`).
- File and component names in PascalCase. `<style scoped>`; no SCSS.
- **Create and edit share one form component** (as `AgeingConfigForm.vue` for `CreateAgeingConfig.vue` / `EditAgeingConfig.vue`): the pages own the API calls, the buttons and the dialogs; the form owns the fields.
- Page names, route names and route paths follow the module's newest screens (incentive: `CreateAgeingConfig`, `EditAgeingConfig`, `OverdueDateConfigDetail`; route names like `AgeingConfigCreate`; paths like `:schemaId/ageing-configs/:configId/edit`).

### Reuse, never re-create
| Need | Use |
|---|---|
| A button | `src/components/BaseButton.vue` |
| Loading | `LoadingSpinner.vue` |
| A load error ("Gagal Memuat", with "Muat Ulang") or an empty state | `MessageCard.vue` |
| A table | `BaseDataTable.vue` (ag-grid; pagination and `@page-change`); cell renderers as Vue components |
| A confirmation (save, discard, status change) | `ConfirmationDialog.vue` |
| The breadcrumb | `Breadcrumb.vue` (`items: { label, to? }[]`) |
| Text and number inputs | `BaseInput.vue`; numbers and decimals with `BaseInputNumber.vue` (never a raw `type="number"`) |
| A dropdown or a search | `FormDropdown.vue`, `SearchableFilter.vue` |
| A status label | `StatusBadge.vue` |
| Any message to the user | `useAppToast()` (`showToast.success/error/info/warning`); never `BaseToast` (deprecated) |
| Leaving a form with changes | `useUnsavedChangesGuard()` |
| A feature switched on per environment | `useFeatureFlags()` and the route guard `requireFeature('<key>')` |
| Permissions | `hasPermission(menuKey, action)`, `useCurrentRoutePermission()`, `meta.permissions` on the route |
| Dates on screen | `formatDate` (DD/MM/YYYY) and `formatDateTime` from `src/utils/dateFormatter.ts`; never `formatDateShort` |
| Money and numbers on screen | `formatToRupiah`, `formatNumberID` from `src/utils/stringFormatter.ts` |
| Pagination defaults | `DEFAULT_PAGE`, `DEFAULT_LIMIT` from `src/constants/pagination.ts` |

### Talking to the backend
- **One function per endpoint** in `src/api/<module>.ts`, named `getX`, `createX`, `updateX`, `patchXStatus`, `deleteX`, typed `Promise<XSuccessResponse | ErrorResponse>`.
- It **returns** an `ErrorResponse` (`status`, `error_code`, `message`, `details`) and never throws, except when the call was cancelled (`AbortError` / `ERR_CANCELED`): that is thrown again. The backend's `message` is passed through as it is (`?? ''`), so the screen can fall back to its own copy.
- The URL from the module's base variable (e.g. `VITE_INCENTIVE_BASE_URL`); headers `accept: 'application/json'`, and `'X-Secure-Transmission-Type': 'x'` on writes (POST, PUT, PATCH, DELETE); loads take an `AbortSignal` (the page keeps an `AbortController` and aborts it when it leaves).
- Types: the module's `XSuccessResponse` and the shared `ErrorResponse` (`src/common-types/error.ts`).
- The page checks `response.status === 'success'`.

### Error messages
- The error codes are the backend's (rule A16): the page shows the backend's `message` when there is one, else the screen's own Indonesian copy for that code.
- The mapping from an `error_code` (and `details.missing_or_invalid`) to where it shows (a field, the page banner, a toast, a not-found state) lives in the module's utils, as `ageingConfigValidation.ts` does; field errors as `<p class="error-message">`, page errors as `<p class="banner-error">`.
- Field checks (required, ranges, decimals) are plain functions in `utils/<x>Validation.ts` returning `''` or a message; errors show after the field was touched, or for every field after Simpan. The backend checks everything again: the web app's checks are for the user, never the only check.

### Wording
- Indonesian, in the page or the module's `constants/` (the app has no translation files). Reuse the module's existing copy for the same thing (e.g. "Simpan", "Batal", "Gagal Memuat", "Field ini wajib diisi").

### Routes, menu, breadcrumbs
- Routes in the module's `routes.ts`: a parent path with `meta: { requiresAuth: true, permissions }` and `beforeEnter` guards (`requireFeature(...)`, `authorizeRoutePermissionAccess(...)` where the module uses it), the screens as children; registered in `src/router/index.js`.
- A new menu entry: its label in `src/components/AppSidebar.vue`, with the same visibility checks as its siblings (feature flag, permission).
- Each page sets its own breadcrumb (`Breadcrumb` with the labels of the menu path).

### Test ids (new screens only; user, 2026-10-19)
- A new screen gets `<Screen>.testids.ts` (an `as const` object, ids like `<scope>-<section>-<element>`, as `src/views/Login.testids.ts`) and passes them through the `testid` prop of `BaseButton`, `BaseInput`, `BaseInputNumber` and `Toggle`, or `data-testid` on other elements. Existing screens aren't changed for this.

### Style
- As `.prettierrc` says: 2 spaces, single quotes, semicolons, trailing commas (es5), 100 characters a line, LF. (Prettier isn't installed in the repo; the code is written that way.)
- TypeScript in new files; no new `any` where the type is known.
- Every file ends with a newline.

---

## Step 6 — Write tests

**Vitest**, in the repo ([D24](../docs/design-decisions.md#d24): Playwright stays outside it).

- **Where:** `__tests__/` next to the code: `src/views/<module>/__tests__/<File>.test.ts` (the module's components and utils too), `src/api/__tests__/<module>.test.ts`, `src/components/__tests__/`, `src/composables/__tests__/`. Files are `*.test.ts`. Shared test data in `src/__tests__/fixtures/`.
- **A page:** `mount` (never `shallowMount`) with child components stubbed (`global.stubs`); the API mocked with `vi.mock('@/api/<module>', …)` and mocks made in `vi.hoisted`; `vue-router` mocked (`useRoute`, `useRouter` with a `push` mock, `RouterLink`); `useAppToast` mocked; Pinia with `setActivePinia(createPinia())` when the page uses a store; `await flushPromises()` after mounting; `vi.useFakeTimers()` for the delayed navigation after a save.
- **What a page test asserts:** the API called with the exact arguments and payload; the loading, error, empty, not-found and retry states; the rendered values and copy; the toasts; the navigation (`push`); disabled buttons; the unsaved-changes guard.
- **An API module:** axios mocked (`vi.mock('../axios', …)`), `vi.stubEnv` for the base URL; asserts the URL, the method, the params, the headers (`X-Secure-Transmission-Type: 'x'` on writes), the returned success and error shapes, the network error, and that a cancel is thrown again.
- **A utils file:** plain function tests, no mounting.
- **Naming:** `describe('<Component>.vue')`, then a `describe` per behaviour; `it` titles as plain sentences of what happens. A `describe('AC <n> — <title>')` per acceptance criterion is fine (as `EditAgeingConfig.test.ts`).
- Imports `describe`, `it`, `expect`, `vi` from `'vitest'` explicitly.
- Every AC is covered, its error paths too.

---

## Step 7 — Run tests

`bash scripts/repo-run.sh closio-web-v2 test` (the repo's `npm run test:coverage`: every test and the coverage report in one run, on Node 22). The repo's coverage aim is 70% for branches, functions, lines and statements; see "Known problems" for why the run doesn't fail below it.

---

## Step 8 — Browser checks

`flow-verify` writes and runs Playwright tests **outside the repo** (`runs/<KEY>/e2e/`, [D24](../docs/design-decisions.md#d24)), against the dev APIs; an API not on dev yet is mocked with the exact 200 response the user gives ([D69](../docs/design-decisions.md#d69)). The quick check uses one-off Playwright tests. A new screen's test ids (Step 5) make these checks steady.

---

## Step 9 — Verify and ship

- Read every edited file once more: the routes registered, the menu entry, the breadcrumbs, no leftover debug output.
- `flow-push`: the rebase onto `development` (every AC checked again the quick way when it had a conflict or brought newer commits, [D83](../docs/design-decisions.md#d83)), atomic commits (`<KEY>: <what this commit does>`), the MR into `development`, titled `<KEY>: <card title>`.
- `flow-review`: the self-review with [code-review.md](code-review.md) (its web-app part) and this ruleset, then the reviewers' comments.

---

## Known problems in the web app (don't copy them; not fixed inside unrelated cards)

Found on `development` on 2026-10-19; left as they are (user, 2026-10-19).
- `formatDateShort` (`src/utils/dateFormatter.ts`) shows dates as D/M/YYYY; three incentive detail pages use it (`PayoutConfigDetail.vue`, `OverdueDateConfigDetail.vue`, `IncentiveSchemaDetail.vue`). New screens use `formatDate`.
- `vitest.config.js` puts the 70% thresholds under a `global` key that Vitest 3 doesn't read, so a test run doesn't fail below 70%.
- `BaseToast` is deprecated but still mounted in about 21 pages; new code uses `useAppToast`.
- Some API modules throw instead of returning an `ErrorResponse` (`src/api/fields.ts`, `customerLeads.ts`, `travelPlan.ts`, `auth.js`); new functions return it.
- `src/api/mocks/` is still imported at runtime by a few modules (e.g. `src/api/order.ts`); new code never uses mocks at runtime.
- The permission check on `/incentive/schemas` (`authorizeRoutePermissionAccess`) is commented out in `src/views/incentive/routes.ts`.
- Helpers written more than once (reuse the shared one): `CLIENT_SIDE_CODES` (`incentive/utils/overdueDate.ts` and `EditAgeingConfig.vue`); `periodFromIsoDate` vs `periodFromIso` (`src/utils/periodKey.ts`); inline YYYY-MM-DD formatters vs `formatDateToISO` (`src/utils/dateHelpers.ts`); `formatThousands` in two input components; an error-response builder repeated in every API module.
- The README is out of date (Node version, port, mock files); the code is the reference.

---

## Checklist (copy for each web card)

- [ ] Card read: the screens, their menu path, the APIs and their error codes
- [ ] The four exploration questions answered
- [ ] The reference screen set and the closest screen read end to end
- [ ] Every needed helper, component and type searched for first (rule A21)
- [ ] Plan presented and approved
- [ ] API functions: return `ErrorResponse`, rethrow a cancel, `'x'` header on writes, an `AbortSignal` on loads
- [ ] Types in the module's `types/`
- [ ] Checks, payload and error mapping as plain functions in the module's `utils/`
- [ ] Create and edit share one form component
- [ ] Shared components reused (`BaseButton`, `LoadingSpinner`, `MessageCard`, `BaseDataTable`, `ConfirmationDialog`, `Breadcrumb`, `BaseInputNumber` …)
- [ ] Messages through `useAppToast`; dates through `formatDate`
- [ ] Loading, error, empty and not-found states on every page that loads data
- [ ] Routes in `routes.ts` with `meta.permissions` and guards; menu entry and breadcrumbs
- [ ] Test ids for a new screen (`<Screen>.testids.ts`)
- [ ] Tests: the pages, the API functions, the utils; every AC and its error paths
- [ ] Tests pass (`bash scripts/repo-run.sh closio-web-v2 test`)
- [ ] Browser checks with `flow-verify`
- [ ] Self-review with `flow-review`; MR into `development`
