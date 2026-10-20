# Jira card examples

Three real cards from the SCRUM board, in the shape of the [card template](jira-card-template.md) ([D58](design-decisions.md#d58), [D82](design-decisions.md#d82)). Copy their structure, not their content. A and B are backend cards; C is a web card.

- All three were edited only to match the template; the edits are listed under each title. **The cards in Jira weren't changed.**
- `<B1_PARTNER_ID>` stands for the Business 1 partner ID, which is written in the real card but not in these docs. `<SP_ID>`, `<T1_ID>` and the like are values QA picks themselves.
- All three pass `bash scripts/card-check.sh` with no ❌ (checked 2026-10-20). The ⚠️ lines are the SQL revert and cleanup steps, which have no "Expect".

---

# Example A: SCRUM-559 (Task, compact)

Edits:
- AC headings changed from `**AC1: …**` to `**AC 1 — …**`.
- The `**Not in scope:**` line moved from Context into a `## Out of Scope` section (the only place for out-of-scope, D58). The dev note that was in the same line stays in Context.
- The partner ID is replaced.
- 2026-10-20 (D82):
  - a User Story line;
  - each QA step names its AC;
  - a new step 13 for AC 6 (the earlier `SLAB_SET_NOT_FOUND` check, 404 in the code), and step 12 reworded to say "Expect";
  - a cleanup step;
  - the Error reference with "Raised by".

**Summary:** Backend Business 1 - Return VALIDATION_ERROR for channel errors on PATCH Incentive Point Slab Set
**Link:** relates to SCRUM-538

As the web app, I want POST and PATCH Incentive Point Slab Set to return the same error code for a channel mistake, so that the user sees one error, whichever screen they save from.

## Context

**Current gap:** POST and PATCH Incentive Point Slab Set return different error codes for the same channel mistake.

* **POST** `/api/incentives/v1/incentive-points/:incentive_point_metric_id/slab-configs` returns `400 VALIDATION_ERROR`.
* **PATCH** `/api/incentives/v1/incentive-points/:incentive_point_metric_id/slab-configs/:slab_config_id` (with `is_slabs_updated = true`) returns `400 INVALID_CHANNEL`.

The messages are already the same on both endpoints:

* `channel is required for this incentive point`: when the incentive point has `requires_channel = true` and a group's `channel` is missing, null, not a string or blank.
* `channel must not be provided for this incentive point`: when the incentive point has `requires_channel = false` and a group includes a `channel` key.

**What changes:** PATCH returns `VALIDATION_ERROR` for both cases, the same as POST. The messages stay the same. After this change, neither endpoint returns `INVALID_CHANNEL`. This replaces the `INVALID_CHANNEL` rows in SCRUM-484's validation rules and error table.

**Why:** the frontend and QA should see one error code for a channel mistake, whichever endpoint the user saves from. Channel whitelist errors (SCRUM-538) will also use `VALIDATION_ERROR`.

**Dev note:** the implementation approach is up to the developer.

## How QA can test this

Use the Business 1 partner (`<B1_PARTNER_ID>`) with the usual headers/token for the incentive APIs. Seeded incentive points:

* `NT_VOLUME_ACHIEVEMENT`, id `10000000-0000-4000-8000-000000000001` (`requires_channel = true`)
* `TR_STOCK_BY_PRODUCT`, id `10000000-0000-4000-8000-000000000006`

The config must be in a future period. Otherwise PATCH stops earlier with `SLABS_NOT_EDITABLE` or `EDIT_NOT_PERMITTED` and never reaches the channel check. Pick a month with no active config for that incentive point; otherwise POST returns `CONFIG_OVERLAP`. The steps below use `2026-12`.

**A. Channel missing on a channel-required incentive point**

Body used in step 1 (call it the _base body_):

```json
{
  "valid_from": "2026-12",
  "valid_to": "2026-12",
  "groups": [
    { "channel": "CATERING", "salesperson_type": "NON_TRADER", "level": 1,
      "slabs": [ { "band_order": 1, "operator": ">=", "value": 90, "points": 1 } ] }
  ]
}
```

1. Create a config: `POST /api/incentives/v1/incentive-points/10000000-0000-4000-8000-000000000001/slab-configs` with the base body. Expect `201` with a `slab_config_id`. Note it down.
2. `PATCH /api/incentives/v1/incentive-points/10000000-0000-4000-8000-000000000001/slab-configs/<slab_config_id>` with `"is_config_updated": false, "is_slabs_updated": true` and the base body's group but **without** the `channel` key. Expect `400`, `error_code: "VALIDATION_ERROR"`, message `channel is required for this incentive point` (AC 1).
3. Repeat step 2 with `"channel": ""`, then `"channel": "   "`, then `"channel": null`. Expect the same 400 `VALIDATION_ERROR` each time (AC 1).
4. Call `GET /api/incentives/v1/incentive-points/10000000-0000-4000-8000-000000000001/slab-configs/<slab_config_id>`. Expect the slabs from step 1, unchanged: no slab rows were changed (AC 1).
5. Send the base body to POST again, but without the `channel` key. Expect the same 400 `VALIDATION_ERROR` and message as PATCH. The channel check runs before the overlap check, so reusing `2026-12` is fine here (AC 3).

**B. Channel sent on an incentive point that does not take one**

If `TR_STOCK_BY_PRODUCT` already has `requires_channel = true` (after SCRUM-538), switch it off for this test and switch it back at the end:

```sql
UPDATE incentive_point_metrics SET requires_channel = false
WHERE id = '10000000-0000-4000-8000-000000000006';
```

6. Create a config: `POST /api/incentives/v1/incentive-points/10000000-0000-4000-8000-000000000006/slab-configs` with `valid_from`/`valid_to` `2026-12` and a group `{ "salesperson_type": "TRADER", "level": 1, "slabs": [ { "band_order": 1, "operator": ">=", "value": 50, "points": 5 } ] }` (no `channel` key). Expect `201` and note the `slab_config_id`.
7. PATCH that config with `"is_config_updated": false, "is_slabs_updated": true` and the same group plus `"channel": "TRADER"`. Expect `400`, `error_code: "VALIDATION_ERROR"`, message `channel must not be provided for this incentive point` (AC 2).
8. Repeat step 7 with `"channel": null`. Expect the same error: the key being present is enough (AC 2).
9. If you ran the SQL above, revert it:

```sql
UPDATE incentive_point_metrics SET requires_channel = true
WHERE id = '10000000-0000-4000-8000-000000000006';
```

**C. Nothing else changed**

10. PATCH the config from step 1 with `"is_config_updated": true, "is_slabs_updated": false, "updated_valid_from": "2026-12", "updated_valid_to": "2026-12"` and no `groups`. Expect `200`: the channel is not checked when slabs are not being updated (AC 5).
11. PATCH the config from step 1 with `"is_slabs_updated": true`, a valid `channel` (`CATERING`) and new slabs. Expect `200`, and the response groups show the new slabs.
12. Check every response above. Expect `INVALID_CHANNEL` never to appear (AC 4).
13. `PATCH /api/incentives/v1/incentive-points/10000000-0000-4000-8000-000000000001/slab-configs/<a random UUID that is not a config>` with the body of step 2 (no `channel`). Expect `404`, `error_code: "SLAB_SET_NOT_FOUND"`, not `VALIDATION_ERROR`: the earlier check still wins (AC 6).

**D. Cleanup**

14. Deactivate the configs from steps 1 and 6: `PATCH /api/incentives/v1/incentive-points/<incentive point id>/slab-configs/<slab_config_id>/status` with `{ "status": "inactive" }`. Expect `200` each time, so `2026-12` is free for the next run.

## Acceptance Criteria

**AC 1 — Missing channel on PATCH returns VALIDATION_ERROR**

* **Given** an incentive point with `requires_channel = true` and a slab config in a future period
* **When** PATCH is called with `is_slabs_updated = true` and a group whose `channel` is missing, null, not a string or blank
* **Then** the API returns `400` with `error_code: "VALIDATION_ERROR"` and message `channel is required for this incentive point`, and no slab rows are changed

**AC 2 — Channel provided on PATCH when not applicable returns VALIDATION_ERROR**

* **Given** an incentive point with `requires_channel = false` and a slab config in a future period
* **When** PATCH is called with `is_slabs_updated = true` and any group includes a `channel` key (any value, including null)
* **Then** the API returns `400` with `error_code: "VALIDATION_ERROR"` and message `channel must not be provided for this incentive point`, and no slab rows are changed

**AC 3 — POST and PATCH match**

* **Given** the same invalid `groups` payload
* **When** it is sent to POST and to PATCH (`is_slabs_updated = true`)
* **Then** both return the same `400 VALIDATION_ERROR` and the same message

**AC 4 — INVALID_CHANNEL is no longer returned**

* **Given** any channel mistake on POST or PATCH Incentive Point Slab Set
* **When** the request is rejected
* **Then** `error_code` is never `INVALID_CHANNEL`

**AC 5 — Channel not checked when slabs are not updated**

* **Given** a PATCH with `is_slabs_updated = false`
* **When** the request is processed
* **Then** no channel check runs and the request behaves exactly as today

**AC 6 — Existing checks and their order are unchanged**

* **Given** a PATCH that would also fail an earlier check (`INCENTIVE_POINT_NOT_FOUND`, `SLAB_SET_NOT_FOUND`, `EDIT_NOT_PERMITTED`, `SLABS_NOT_EDITABLE`, `VALID_FROM_NOT_EDITABLE`, `SLAB_NOT_ALLOWED_FOR_DEDUCTION_COMPONENT`)
* **When** the request is processed
* **Then** that earlier error is returned, as today, and the rest of the validation behaves as it does now

**Error reference** (existing codes; PATCH now uses `VALIDATION_ERROR` instead of `INVALID_CHANNEL`)

| HTTP | error_code | message | details | Raised by | Trigger |
| --- | --- | --- | --- | --- | --- |
| 400 | `VALIDATION_ERROR` | channel is required for this incentive point | — | WS2 | `requires_channel = true`, a group's channel missing, null, not a string or blank (AC 1, AC 3) |
| 400 | `VALIDATION_ERROR` | channel must not be provided for this incentive point | — | WS2 | `requires_channel = false`, a group has a `channel` key (AC 2, AC 3) |
| 404 | `INCENTIVE_POINT_NOT_FOUND` | Incentive point does not exist. | — | WS2 | Earlier check, unchanged (AC 6) |
| 404 | `SLAB_SET_NOT_FOUND` | Incentive point slab set does not exist. | — | WS2 | The slab config doesn't exist; earlier check, unchanged (AC 6, step 13) |
| 400 | `EDIT_NOT_PERMITTED` | Config cannot be edited because its period is fully in the past. | — | WS2 | Earlier check, unchanged (AC 6) |
| 400 | `SLABS_NOT_EDITABLE` | Slabs cannot be edited once the config period has started. | — | WS2 | Earlier check, unchanged (AC 6) |
| 400 | `VALID_FROM_NOT_EDITABLE` | valid_from cannot be changed once the config period has started. | — | WS2 | Earlier check, unchanged (AC 6) |
| 400 | `SLAB_NOT_ALLOWED_FOR_DEDUCTION_COMPONENT` | Slab configuration is not allowed for a DEDUCTION component. | — | WS2 | Earlier check, unchanged (AC 6) |

## Out of Scope

* Any other validation, check order, message or response shape change.

---

# Example B: SCRUM-567 (Task, every section of the newest template)

Edits:
- The AC self-check table is removed.
- The "Where" column with file and function names is removed from the first Context table (names go in the text, and only when needed). The Scope and Dev notes still name files where the dev needs the exact spot.
- The partner ID is replaced.
- 2026-10-20 (D82):
  - a User Story line;
  - each QA step names its AC;
  - a cleanup step;
  - a "Raised by" column in the Error reference.

**Summary:** Backend - Add details.missing_or_invalid to every channel validation error (Slab, Ageing, Target APIs)

**Blocked by:** SCRUM-559

As the web app, I want every channel validation error on the Slab, Ageing and Target APIs to name the failing field in `details.missing_or_invalid`, so that the screen can point at the right field on every API.

## Context

**Current gap:** the same channel mistake (missing, null, blank or not a string) gets a different error shape depending on the API. QA found this while testing SCRUM-564.

| API | Today |
| --- | --- |
| Slab POST `/api/incentives/v1/incentive-points/:incentive_point_metric_id/slab-configs` | `400 VALIDATION_ERROR`, message `channel is required for this incentive point` / `channel must not be provided for this incentive point`, **no** `details` |
| Slab PATCH `.../slab-configs/:slab_config_id` (`is_slabs_updated: true`) | `400 INVALID_CHANNEL`, same messages, no `details`. **SCRUM-559 changes the code to** `VALIDATION_ERROR`. |
| Ageing POST `/api/incentives/v1/ageing-deduction-configs` (PATCH: SCRUM-521) | `400 VALIDATION_ERROR`, message `Request validation failed`, `details.missing_or_invalid: ["channels[<i>].channel"]` |
| Target create/update `/api/target/v1/target-type/:targetTypeId/target-value[/:recordId]` (T1/T2) | Missing, null or blank: `400 MISSING_REQUIRED_DIMENSIONS`, `details.missing_fields: ["channel"]`. **Not a string: no check, so it ends in** `500 INTERNAL_ERROR` ("Could not validate target uniqueness") |

**What changes:** every channel validation error on these APIs returns `400 VALIDATION_ERROR` with `details.missing_or_invalid` naming the channel field. Each API **keeps its own existing message** and its own field naming:

| API | message (unchanged, already translated in WS1) | `details.missing_or_invalid` |
| --- | --- | --- |
| Slab POST and PATCH | `channel is required for this incentive point` / `channel must not be provided for this incentive point` | `["groups[<i>].channel"]` (new; `<i>` = index of the failing group in the request) |
| Ageing POST and PATCH | `Request validation failed` | `["channels[<i>].channel"]` (no change) |
| Target create/update (T1/T2), channel not a string | `Request body validation failed` | `["channel"]` (new check) |

The SCRUM-538 channel whitelist error (not built yet) has already been updated to carry `missing_or_invalid: ["groups[<i>].channel"]` too.

**Why:** the Web and QA can read the failing field the same way on every API, without depending on the message text.

## Scope (WS2 only)

**1. Slabs** (`incentivePointSlabUtils.js`)

* `validateAndNormalizeGroups`, used by POST and PATCH: both channel errors keep their code and message and add `details: { missing_or_invalid: ["groups[<i>].channel"] }`. The two errors are:
    * `requires_channel = true` with a missing, null, non-string or blank channel
    * `requires_channel = false` with a `channel` key present
* `assertGroupsChannelUsage` (PATCH only): after SCRUM-559 it returns `VALIDATION_ERROR`; this card adds the same `details`. The developer may instead remove it and rely on `validateAndNormalizeGroups`, as long as the response and check order stay the same.

**2. Ageing:** no code change. It already matches. Listed here for regression only.

**3. Targets** (`src/services/targets/targetTypeValuesService.js`, `createTargetValue` and `updateTargetValue`)

* Add a check right after `validateRequiredDimensions`, only for target types whose `requiredDataFields` include `channel` (T1/T2): if `data.channel` is present but not a string, return `400 VALIDATION_ERROR`, message `Request body validation failed`, `details: { missing_or_invalid: ["channel"] }`.
* It runs before the duplicate check, so the 500 goes away.
* Missing, null or blank channel still returns `MISSING_REQUIRED_DIMENSIONS`, unchanged.
* Target types without `channel` (T3–T5) ignore `data.channel`, as today.

**Check order is unchanged everywhere.** Earlier errors still win:

* slab PATCH: `INCENTIVE_POINT_NOT_FOUND`, `SLAB_SET_NOT_FOUND`, `EDIT_NOT_PERMITTED`, `SLABS_NOT_EDITABLE`, `VALID_FROM_NOT_EDITABLE`, `SLAB_NOT_ALLOWED_FOR_DEDUCTION_COMPONENT`
* targets: target type, date and record-not-found errors

A slab PATCH with `is_slabs_updated: false` never checks the channel.

**Dev notes**

* **Blocked by SCRUM-559** (slab PATCH `INVALID_CHANNEL` → `VALIDATION_ERROR`). Build on top of it, or on the same branch if it isn't merged yet.
* **Targets message:** use exactly `Request body validation failed` with **no trailing space**. That is the key WS1 translates (`locales/id/target-sales/messages.json`). The existing controller message `'Request body validation failed '` (`targetTypeValuesController.js:214`) has a trailing space and isn't touched by this card.
* **WS1 is unchanged.**
    * Incentive errors are rebuilt by `createError`: the message is translated and `upstream_*` keys are added to `details`.
    * Target errors are passed through with only the message translated.
    * `missing_or_invalid` reaches Closio in both cases.
    * WS1's slab schemas only allow `string`/`null` for `channel`, so through WS1 a number is rejected earlier with `GENERAL_ERROR`. That's why QA tests on WS2 directly.
* SCRUM-564's HORE normalising is unaffected, because the channel checks run before or on the raw value exactly as today.

## How QA can test this

**Setup**

* Call **WS2 directly**, using partner `<B1_PARTNER_ID>`.
* Headers: `x-client-id`, `x-client-secret`, `X-Partner-Id`, `X-User-Id`, `X-User-Name`.
* Incentive points: `NT_VOLUME_ACHIEVEMENT` = `10000000-0000-4000-8000-000000000001` (`requires_channel = true`), `TR_STOCK_BY_PRODUCT` = `10000000-0000-4000-8000-000000000006`.
* Use future months with no active config for that incentive point (e.g. `2027-04` onwards). Otherwise POST returns `CONFIG_OVERLAP`, and PATCH stops earlier with `SLABS_NOT_EDITABLE` / `EDIT_NOT_PERMITTED`.
* Target type ids:

```sql
SELECT id, table_name FROM target_types
WHERE table_name IN ('target_sales_volume_all_customers','target_sales_volume_new_customers','target_call_plan');
```

* Pick a level-1 salesperson id (`<SP_ID>`).

**A. Slab POST, channel required** (`NT_VOLUME_ACHIEVEMENT`)

Base group: `{ "channel": "CATERING", "salesperson_type": "NON_TRADER", "level": 1, "slabs": [ { "band_order": 1, "operator": ">=", "value": 90, "points": 1 } ] }`

1. POST with the base group but no `channel` key. Expect `400`, `error_code: "VALIDATION_ERROR"`, message `channel is required for this incentive point`, `details.missing_or_invalid: ["groups[0].channel"]` (AC 1).
2. Repeat with `"channel": null`, `""`, `"   "`, `123`, `true`, `[]`, `{}`. Expect the same each time (AC 1).
3. Send two groups (`level` 1 and 2), where only the second has `"channel": 123`. Expect `details.missing_or_invalid: ["groups[1].channel"]` (AC 1).
4. POST with the valid base group. Expect `201`. Note the `slab_config_id`.

**B. Slab PATCH** (the config from step 4, `"is_config_updated": false, "is_slabs_updated": true`)

5. Repeat steps 1–3 as PATCH bodies. Expect the same responses. `INVALID_CHANNEL` never appears (AC 1, AC 3).
6. PATCH with `"is_config_updated": true, "is_slabs_updated": false` and the same period (`updated_valid_from` / `updated_valid_to`). Expect `200`: the channel isn't checked (AC 8).
7. `GET .../slab-configs/<slab_config_id>`. Expect the slabs from step 4, unchanged: nothing was saved (AC 1).

**C. Slab, channel not allowed** (`TR_STOCK_BY_PRODUCT`)

8. If SCRUM-538 has already flipped Trader metrics, switch it back for this test:

```sql
UPDATE incentive_point_metrics SET requires_channel = false WHERE id = '10000000-0000-4000-8000-000000000006';
```

9. POST with `{ "channel": "TRADER", "salesperson_type": "TRADER", "level": 1, "slabs": [ { "band_order": 1, "operator": ">=", "value": 50, "points": 5 } ] }`. Expect `400 VALIDATION_ERROR`, message `channel must not be provided for this incentive point`, `details.missing_or_invalid: ["groups[0].channel"]`. Repeat with `"channel": null` and expect the same; the key being present is enough (AC 2).
10. POST the same group without `channel`. Expect `201`. PATCH that config (`"is_slabs_updated": true`) with `"channel": "TRADER"`. Expect the same error as step 9 (AC 2).
11. If you ran step 8, revert it:

```sql
UPDATE incentive_point_metrics SET requires_channel = true WHERE id = '10000000-0000-4000-8000-000000000006';
```

**D. Ageing (regression; should already pass)**

12. `POST /api/incentives/v1/ageing-deduction-configs` (free period) with `channels[0].channel` set to `123`, `null`, `""`, missing, and a 101-character string. Expect `400 VALIDATION_ERROR`, message `Request validation failed`, `details.missing_or_invalid: ["channels[0].channel"]` each time (AC 4).

**E. Targets** (T1, current month)

13. `POST /api/target/v1/target-type/<T1_ID>/target-value` with `{ "start_date": "2026-10-01", "end_date": "2026-10-31", "target_value": 1000, "data": { "salesperson_id": "<SP_ID>", "salesperson_name": "QA SP", "channel": 123 } }`. Expect `400 VALIDATION_ERROR`, message `Request body validation failed`, `details.missing_or_invalid: ["channel"]` (not 500) (AC 5).
14. Repeat step 13 with `true`, `{}` and `["HORE"]`. Expect the same (AC 5).
15. Repeat step 13 with no `channel`, then `""`. Expect `400 MISSING_REQUIRED_DIMENSIONS` with `details.missing_fields: ["channel"]` (unchanged) (AC 6).
16. Create a valid T1 target with `"channel": "QSR"`. Expect `201`. PATCH it (`/target-value/<id>`) with the same body and `"channel": 123`. Expect the step 13 error (AC 5). Then check the original row is still `ACTIVE`:

```sql
SELECT status FROM target_sales_volume_all_customers WHERE id = '<id>';
```

17. Repeat step 13 on `<T2_ID>` with another salesperson. Expect the same (AC 5).
18. On the `target_call_plan` type, POST a valid body for that type (its own `salesperson_type_id` / `salesperson_type_name`) plus `"channel": 123` inside `data`. Expect the same result as without `channel` (it's ignored) (AC 7).
19. Nothing was saved by the failed calls:

```sql
SELECT count(*) FROM target_sales_volume_all_customers
WHERE salesperson_id = '<SP_ID>' AND created_at > now() - interval '1 hour';
```

Expect only the row(s) from step 16 (AC 5).

**F. Cleanup**

20. Deactivate the slab configs from steps 4 and 10: `PATCH /api/incentives/v1/incentive-points/<incentive point id>/slab-configs/<slab_config_id>/status` with `{ "status": "inactive" }`. Expect `200` each time. Then delete the target rows from steps 16 and 18:

```sql
DELETE FROM target_sales_volume_all_customers WHERE id = '<id from step 16>';
DELETE FROM target_call_plan WHERE id = '<id from step 18>';
```

## Acceptance Criteria

**AC 1 — Slab: channel required**

* **Given** an incentive point with `requires_channel = true`
* **When** slab POST, or PATCH with `is_slabs_updated: true`, has a group whose `channel` is missing, null, blank or not a string
* **Then** HTTP 400 `VALIDATION_ERROR`, message `channel is required for this incentive point`, `details.missing_or_invalid: ["groups[<i>].channel"]` for the first failing group. Nothing is saved.

**AC 2 — Slab: channel not allowed**

* **Given** an incentive point with `requires_channel = false`
* **When** any group has a `channel` key (any value, including null)
* **Then** HTTP 400 `VALIDATION_ERROR`, message `channel must not be provided for this incentive point`, `details.missing_or_invalid: ["groups[<i>].channel"]`. Nothing is saved.

**AC 3 — Slab: no INVALID_CHANNEL**

* **Given** any channel mistake on slab POST or PATCH
* **When** it is rejected
* **Then** `error_code` is never `INVALID_CHANNEL`.

**AC 4 — Ageing unchanged**

* **Given** ageing POST (or PATCH, SCRUM-521)
* **When** a channel is missing, null, blank, not a string or longer than 100 characters
* **Then** HTTP 400 `VALIDATION_ERROR`, message `Request validation failed`, `details.missing_or_invalid: ["channels[<i>].channel"]`, as today.

**AC 5 — Target: channel not a string**

* **Given** a T1 or T2 target type
* **When** create or update has `data.channel` present but not a string
* **Then** HTTP 400 `VALIDATION_ERROR`, message `Request body validation failed`, `details.missing_or_invalid: ["channel"]`. No 500. Nothing is saved, and on update the existing row stays `ACTIVE`.

**AC 6 — Target: channel missing (unchanged)**

* **Given** a T1 or T2 target type
* **When** `data.channel` is missing, null or blank
* **Then** HTTP 400 `MISSING_REQUIRED_DIMENSIONS` with `details.missing_fields` including `channel`, as today.

**AC 7 — Target types without channel**

* **Given** a target type without `channel` in its required fields (T3–T5)
* **When** `data.channel` is sent with any value
* **Then** it is ignored, as today.

**AC 8 — Order and everything else unchanged**

* **Given** a request that would also fail an earlier check
* **When** it is processed
* **Then** that earlier error is returned, as today. A slab PATCH with `is_slabs_updated: false` never checks the channel. Valid channels behave exactly as today, including SCRUM-564's HORE normalising.

**Error reference** (existing codes and messages; only `details` is added)

| HTTP | error_code | message | details | Raised by | Trigger |
| --- | --- | --- | --- | --- | --- |
| 400 | `VALIDATION_ERROR` | channel is required for this incentive point | `missing_or_invalid: ["groups[<i>].channel"]` | WS2 | AC 1 |
| 400 | `VALIDATION_ERROR` | channel must not be provided for this incentive point | `missing_or_invalid: ["groups[<i>].channel"]` | WS2 | AC 2 |
| 400 | `VALIDATION_ERROR` | Request validation failed | `missing_or_invalid: ["channels[<i>].channel"]` | WS2 | AC 4 (unchanged) |
| 400 | `VALIDATION_ERROR` | Request body validation failed | `missing_or_invalid: ["channel"]` | WS2 | AC 5 |
| 400 | `MISSING_REQUIRED_DIMENSIONS` | Missing required dimension fields for this target type | `missing_fields`, `target_type`, `table_name` | WS2 | AC 6 (unchanged) |

## Out of Scope

* Changing any message text, or adding WS1 locale keys.
* How WS1 relays errors (`createError` wrapping and `upstream_*` keys for incentives, pass-through for targets), and WS1's `GENERAL_ERROR` for a non-string slab channel.
* The trailing space in the existing targets controller message (`'Request body validation failed '`).
* A missing, null or blank target channel, which keeps `MISSING_REQUIRED_DIMENSIONS`.
* Bulk upload's per-row channel error ("Field wajib tidak lengkap (salesperson_id, channel)") and the webhooks' `CSV_ROW_VALIDATION_ERROR`. CSV values are always strings.
* Duplicate-channel errors (`DUPLICATE_AGEING_CHANNEL`, the slab duplicate-group error, `DUPLICATE_OR_OVERLAPPING_TARGET`).
* The target list `?channel=` filter error ("Invalid filter field: channel").
* Non-string values in other target fields (`salesperson_id`, `salesperson_name`, …).
* Any frontend change.

---

# Example C: SCRUM-532 (Story, a web card)

Edits (2026-10-20, D82):
- **Structure:**
  - `### Description` → `## Context`, with "Screens in Scope" and "Screen Changes" under it (`####` per screen).
  - "Dependencies" → the first line `**Blocked by:** SCRUM-531`. Its "Not a blocker" note and the "Technical Notes" → `### Dev notes`.
  - "What This Card Deliberately Does NOT Do" → `## Out of Scope`.
  - A User Story line.
- **Dev notes:** the APIs each screen calls were added, read from the web app's `scrum-532` branch (`src/api/target.ts`). The old Edit note said "fetches `/target-types`"; the code calls `GET <VITE_TARGET_SALES_BASE_URL>/target-type-partner-mapping` (`getTargetTypes`), so it says that now.
- **ACs:** the headings `#### AC N — Title` → `**AC N — Title**`, with `* **Given** / * **When** / * **Then** / * **And**` bullets. The AC text is unchanged except for two:
  - **AC 11:** the note "QA can't trigger this… checked in code review only" is removed; QA step 12 mocks a response instead.
  - **AC 12:** it names the error QA hits in step 9 (`409 DUPLICATE_OR_OVERLAPPING_TARGET`, from the WS2 code), and an Error reference is added.
- **QA steps:** each step ends with "Expect …" and names its AC. New steps: 8 (AC 5, filters), 12 (AC 11, mocked response) and 17 (cleanup).

**Summary:** Frontend —  Target Sales: T2 Display and Input as New Customer Count

**Blocked by:** SCRUM-531

As a web admin, I want to enter a T2 target as a whole number of new customers, so that T2 targets match how SCRUM-531 now measures T2.

## Context

Update the Target Sales web screens so T2 is entered as a **new customer count (whole number)** instead of **Sales Volume (KG)**. The T2 name and labels come from the backend (SCRUM-531), the same way they do for every other target type. This card adds the whole-number input for T2 and the Level 1–3 Salesman list.

### Screens in Scope

| Screen | Route |
| --- | --- |
| Target Sales list | `/target/target-sales` |
| Unggah Target Sales (.csv) modal | `/target/target-sales` |
| Tambah Target Sales Baru | `/target/target-sales/create` |
| Edit Target Sales | `/target/target-sales/:id/edit` |

### Screen Changes

#### Target Sales list

| Element | Current | New |
| --- | --- | --- |
| Skema Sales T2 option | Backend `type_name` "Target sales volume new customers" | Backend `type_name` "Target new customer count" (no frontend change) |
| Value column header | Backend label "Sales Volume (KG)" | Backend label "New Customer Count Target" (no frontend change) |
| Value format | Shown as the backend returns it | No change. The backend returns a number, so 25 shows as `25` |
| Filters, other columns, Aksi | — | No change |

#### Unggah Target Sales (.csv) modal

No frontend change. No unit (KG or COUNT) is shown anywhere in the modal or the downloaded template.

#### Tambah Target Sales Baru (T2)

| Field | Current | New |
| --- | --- | --- |
| Channel \*, Bulan \*, Tahun \* | — | No change (Periode must be next month or later, as today) |
| Salesman \* | Level 1 users | Level 1, 2 and 3 users (not filtered by channel, as today) |
| Value label | Backend label "Sales Volume (KG) \*" | Backend label "New Customer Count Target \*" (no frontend change) |
| Value input | Decimals allowed | `.` blocked when typed or pasted. `-`, `+`, `e` stay blocked as for all types |
| Red message | — | "Target harus berupa bilangan bulat ≥ 0" if the field holds a non-whole value (backup only, see AC 11) |
| Simpan | Enabled when the form is valid | Also disabled while the red message shows |

#### Edit Target Sales (T2)

| Field | Current | New |
| --- | --- | --- |
| Channel, Salesman, Bulan, Tahun | Editable for future-month targets | No change: editable for future-month targets, like other types |
| Salesman list | Level 1 users | Level 1, 2 and 3 users (same as Add) |
| Value label | "Target \*" | No change ("Target \*", like other types) |
| Value input, red message, Simpan | Decimals allowed | Same as Add. Simpan stays disabled until something changes, as today |
| Which rows can be edited | Future-month only | No change |

### Dev notes

* **Not a blocker:** the Salesman dropdown sends `level=1&level=2&level=3` to the existing `/users` endpoint, the same way the focus-group layout sends `[1, 2]`.
* **APIs the screens call** (`src/api/target.ts`; the base URLs come from `VITE_TARGET_SALES_BASE_URL` and `VITE_USERS_BASE_URL`):
    * Skema Sales options: `GET <target sales base>/target-type-partner-mapping` (`getTargetTypes`)
    * Labels: `GET <target sales base>/target-type-details/:id` (`getTargetTypeDetails`)
    * The list, and Edit after a page refresh: `GET <target sales base>/target-type-values/:id` (`getTargetTypeValues`)
    * Salesman list: `GET <users base>/users` with `level` 1, 2 and 3 (`getSalespersons`)
    * Simpan on Add: `POST <target sales base>/target-type/:targetTypeId/target-value` (`createTargetValue`)
    * Simpan on Edit: `PATCH <target sales base>/target-type/:targetTypeId/target-value/:recordId` (`updateTargetValue`)
* **How T2 is detected:** `table_name === 'target_new_customer_count'` or `target_type_id === '39be32fe-d978-45e8-950e-6b6741ed06e6'` (`src/views/target/constants/targetTypes.ts`). The weekly-revenue type is detected the same way. The whole-number input, the red message, the Simpan check and the Level 1–3 Salesman list (Add and Edit) apply only when one of these matches.
* **Labels:** T2 uses the backend labels like every other type. The Add form and list column show the `target_value` field label from target-type details, and Edit shows "Target \*", as for all types. There are no T2 label constants in the frontend.
* **Input:** `BaseInput` with `type="number"` and `allow-decimals=false` for T2. `min=0` is set automatically. There is no `step` attribute, and `,` isn't blocked.
* **Red message:** kept as a backup only. With `.` and `-` blocked and the SCRUM-531 CHECK in place, it can't appear in normal use; QA checks it with a mocked response (step 12).
* **Add URL:** `targetTypeName` comes from the Skema Sales `type_name`, so it updates after the backend rename. Old bookmarked URLs will break; this is accepted.
* **Bulk upload:** the backend reads uploaded rows by header key (`target_value`, etc.), so the template header must stay as the plain keys. The `unit` in the template response is not shown.
* **Edit:** if the store has no cached target type (for example after a page refresh), Edit now fetches the target types (`getTargetTypes`) to find it, the same way Add does. If that fails, it shows "Gagal memuat detail skema target sales".

## How QA can test this

**Setup**

* Log in as a web admin who can create and update Target Sales.
* Check that at least one active **Level 2** and one **Level 3** salesperson exist (`GET /users?level=3` should return users).
* Have DB access to the WS2 target sales DB for steps 13 and 17.
* For step 12: a way to mock one API response (Playwright, or the browser's response override).

**Steps**

1. Open `/target/target-sales` and open **Skema Sales**. Expect the T2 option to read "Target new customer count" (AC 1). Select it.
2. If there are no T2 rows, expect the "Belum ada data target" card with no errors (AC 4).
3. Click **Tambah Target Sales Baru**, then **Tambah Target Sales Baru** in the menu. Expect the value field to be labelled "New Customer Count Target \*" (AC 6).
4. Open **Salesman**. Expect Level 1, 2 and 3 users in the list (AC 13).
5. Click into the value field and type `12.5`. Expect the `.` to be ignored and the field to show `125`. Type `-1`: expect the `-` to be ignored. Paste `12.5`: expect nothing to be pasted (AC 10).
6. Pick a Channel, a **Level 3** salesman, Bulan = next month, Tahun, value `0`. Click **Simpan**. Expect the toast "Target sales berhasil dibuat", then the list, where the row shows `0` under **New Customer Count Target** (AC 9, AC 2).
7. Add another target for a different salesman (Level 2) with value `25`. Expect the list to show `25`, with no decimals and no unit (AC 3, AC 9).
8. With T2 selected, search for the step 7 salesman's name, filter by its Channel and Periode, and click Apply. Expect only the step 7 row. Click Reset. Expect the rows from steps 6 and 7 again, as for other types (AC 5).
9. Add the same salesman + channel + month as step 7 again. Expect the backend to reject it with `409 DUPLICATE_OR_OVERLAPPING_TARGET`: an error toast shows the backend's message, and you stay on the form with your values kept (AC 12).
10. On the `25` row, click **Pilih Aksi → Edit**:

    * Expect the value field to be labelled "Target \*".
    * Expect Channel, Salesman, Bulan, Tahun and the value to be editable, and Simpan disabled until you change something.
    * Open **Salesman**: expect Level 1, 2 and 3 users.
    * Change the salesman to a Level 3 user and the value to `30`, then click Simpan. Expect "Target sales berhasil diperbarui", and the list shows the new salesman and `30` (AC 7, AC 9, AC 13).

11. On Edit, type `12.5` in the value field. Expect the `.` to be ignored (AC 10).
12. **Red message (backup):** mock the response of the `target-type-values/<T2_ID>` call (shown in DevTools → Network): copy its real response and change the `target_value` of the step 10 row to `12.5`. With the mock on, open that row's Edit page and reload it. Expect "Target harus berupa bilangan bulat ≥ 0" under the field, the field red, and Simpan disabled. Clear the field: expect no red message, and Simpan still disabled. Turn the mock off (AC 11).
13. **Current-month row:** copy a row id from the Edit URL (`/target/target-sales/<id>/edit`), then run:

    ```sql
    UPDATE target_new_customer_count
    SET start_date = date_trunc('month', CURRENT_DATE)::date,
        end_date   = (date_trunc('month', CURRENT_DATE) + interval '1 month - 1 day')::date
    WHERE id = '<id>';
    ```

    Reload. Expect Edit to be greyed out in Pilih Aksi (AC 8).

14. **Batal:**

    * On Add, click Batal: expect to go back to the previous page with no prompt.
    * On Edit with no changes, click Batal: expect to go back to the list.
    * On Edit after changing something, click Batal: expect the dialog "Apakah Anda yakin untuk membatalkan perubahan ini?". **Kembali ke Halaman** keeps you on the form; **Batalkan Perubahan** leaves without saving (AC 14).

15. **Upload:**

    * With T2 selected, open **Unggah Data** and click **Unduh Template**. Expect a CSV whose header row is the backend's column keys (e.g. `start_date`, `end_date`, `target_value`), and no unit (KG or COUNT) in the modal or the file's header.
    * Fill in one row with `25` and one with `12.5`, upload it and click **Proses Data**.
    * Open **Riwayat** and click **Muat Ulang**. Expect the status and the source/error CSV links as before, and the `12.5` row in the error CSV with "T2 target value must be a non-negative whole number" (from SCRUM-531) (AC 15, AC 16).

16. **Other types:** switch Skema Sales to T1, T4, T5 and T6. For each, expect:

    * the column and Add labels unchanged;
    * decimals allowed (e.g. `6570.88`);
    * the Salesman list showing Level 1 (T5/T6: Level 1 and 2);
    * on Edit of a future-month row, Channel, Salesman, Bulan and Tahun still editable (AC 17).

17. **Cleanup:** delete every T2 row this test created (steps 6, 7, 10 and 15; the Edit URL shows a row's id):

    ```sql
    DELETE FROM target_new_customer_count WHERE id IN ('<id>', '<id>');
    ```

## Acceptance Criteria

**AC 1 — Skema Sales label**

* **Given** SCRUM-531 is deployed
* **When** an admin opens the Skema Sales dropdown
* **Then** the T2 option shows "Target new customer count" (the backend `type_name`; no frontend change)

**AC 2 — List column header**

* **Given** Skema Sales is set to T2
* **When** the list loads
* **Then** the value column header is the backend label "New Customer Count Target", the same way other types show their backend label

**AC 3 — List value format**

* **Given** a T2 target with `target_value = 25`
* **When** the list renders
* **Then** it shows `25`, with no decimals and no unit

**AC 4 — Empty list**

* **Given** there are no T2 targets
* **When** Skema Sales is set to T2
* **Then** the "Belum ada data target" card shows, with no errors

**AC 5 — Filters unchanged**

* **Given** Skema Sales is set to T2
* **When** the admin searches by name, filters by Channel or Periode, and clicks Apply or Reset
* **Then** the results behave as before

**AC 6 — Add value label**

* **Given** an admin opens Tambah Target Sales Baru for T2
* **When** the form loads
* **Then** the value field shows the backend label "New Customer Count Target \*"

**AC 7 — Edit future-month T2 target**

* **Given** an admin opens Edit for a future-month T2 target
* **When** the form loads
* **Then** the value field is labelled "Target \*", the same as other types
* **And** Channel, Salesman, Bulan, Tahun and the value can all be edited
* **And** the Salesman dropdown lists Level 1, 2 and 3 users
* **And** Simpan stays disabled until something changes

**AC 8 — Edit only for future months**

* **Given** a T2 target for the current or a past month
* **When** the admin opens Pilih Aksi on that row
* **Then** Edit is greyed out and can't be clicked, the same as other single-month types

**AC 9 — Whole number and zero saved**

* **Given** an admin has filled Channel, Salesman, and Bulan/Tahun (next month or later on Add)
* **When** they enter `25` or `0` and click Simpan
* **Then** the target is saved
* **And** the toast "Target sales berhasil dibuat" (Add) or "Target sales berhasil diperbarui" (Edit) shows
* **And** they return to the list

**AC 10 — Non-whole input blocked**

* **Given** an admin is on the Add or Edit T2 form
* **When** they type or paste `.`, `-`, `+`, `e` or `E` into the value field
* **Then** the character is ignored (`-`, `+`, `e`, `E` are already blocked for all types; `.` is now blocked only for T2)

**AC 11 — Red message kept as a backup**

* **Given** the T2 value field holds a non-whole value
* **When** the form renders
* **Then** "Target harus berupa bilangan bulat ≥ 0" shows under the field, the field is red, and Simpan is disabled
* **And** when the field is empty, no red message shows and Simpan is disabled, as for other types

**AC 12 — Backend error shown**

* **Given** the backend rejects a T2 save with `status: "error"`, e.g. `409 DUPLICATE_OR_OVERLAPPING_TARGET` when an active target already exists for the same salesman, channel and month
* **When** Simpan returns
* **Then** an error toast shows the backend `message`, falling back to "Gagal membuat target sales" / "Gagal memperbarui target sales"
* **And** the admin stays on the form with their values kept

**AC 13 — Level 1, 2 and 3 salesmen**

* **Given** an admin is on the Add T2 form, or the Edit form of a future-month T2 target
* **When** they open the Salesman dropdown
* **Then** Level 1, 2 and 3 users are listed (`/users?level=1&level=2&level=3`), with no channel filter, as today

**AC 14 — Batal unchanged**

* **Given** an admin is on the Add or Edit T2 form
* **When** they click Batal
* **Then** Add goes back to the previous page with no prompt
* **And** Edit goes back to the list, or, if something changed, first shows the "Apakah Anda yakin untuk membatalkan perubahan ini?" dialog

**AC 15 — Unggah Data unchanged**

* **Given** Skema Sales is set to T2
* **When** the admin clicks Unduh Template, uploads a file and clicks Proses Data
* **Then** the flow works as before, and the CSV header row is the column keys the backend returns
* **And** no unit (KG or COUNT) is shown in the modal or the template

**AC 16 — Riwayat unchanged**

* **Given** a T2 CSV has been processed
* **When** the admin opens Riwayat and clicks Muat Ulang
* **Then** the status and the source/error CSV links show as before

**AC 17 — Other target types unchanged**

* **Given** Skema Sales is set to T1, T4, T5 or T6
* **When** the list, modal, Add and Edit screens load
* **Then** labels come from the backend as before, decimals are allowed, Salesman levels stay as before (Level 1; T5/T6 Level 1 and 2), and future-month Edit keeps its dimensions editable

**Error reference**

| HTTP | error_code | message | details | Raised by | Trigger |
| --- | --- | --- | --- | --- | --- |
| 409 | `DUPLICATE_OR_OVERLAPPING_TARGET` | An ACTIVE target already exists with the same dimensions and overlapping date range | `existing_target_id`, `existing_start_date`, `existing_end_date`, `requested_start_date`, `requested_end_date` | WS2 (WS1 passes it through) | Same salesman, channel and month as an active target (AC 12, step 9) |
| — | — | Target harus berupa bilangan bulat ≥ 0 | — | Web | The T2 value field holds a non-whole value (AC 11, step 12) |

## Out of Scope

* No T2-specific labels in the frontend: T2 labels come from the backend, like other types
* No changes to the upload modal layout, instructions or Riwayat table
* No unit (KG or COUNT) shown in the bulk upload modal or template
* No changes to filters, Channel, Periode, or the Berlaku sejak / Berlaku sampai columns
* No T1, T4, T5 or T6 screen changes
* No backend validation, template, rename or error CSV changes (SCRUM-531)
* No changes to success or error toasts
* No handling of old bookmarked Add URLs that carry the previous `targetTypeName`
