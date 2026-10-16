# Jira card examples

Two real cards from the SCRUM board, in the shape of the [card template](jira-card-template.md) ([D58](design-decisions.md#d58)). Copy their structure, not their content.

- Both were edited only to match the template; the edits are listed under each title.
- `<B1_PARTNER_ID>` stands for the Business 1 partner ID, which is written in the real card but not in these docs. `<SP_ID>`, `<T1_ID>` and the like are values QA picks themselves.
- Both pass `bash scripts/card-check.sh` with no ❌ (checked 2026-10-17; the ⚠️ lines are the SQL revert steps, which have no "Expect").

---

# Example A: SCRUM-559 (Task, compact)

Edits: AC headings changed from `**AC1: …**` to `**AC 1 — …**`. The `**Not in scope:**` line moved from Context into a `## Out of Scope` section (the only place for out-of-scope, D58); the dev note that was in the same line stays in Context. The partner ID is replaced.

**Summary:** Backend Business 1 - Return VALIDATION_ERROR for channel errors on PATCH Incentive Point Slab Set
**Link:** relates to SCRUM-538

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
2. `PATCH /api/incentives/v1/incentive-points/10000000-0000-4000-8000-000000000001/slab-configs/<slab_config_id>` with `"is_config_updated": false, "is_slabs_updated": true` and the base body's group but **without** the `channel` key. Expect `400`, `error_code: "VALIDATION_ERROR"`, message `channel is required for this incentive point`.
3. Repeat step 2 with `"channel": ""`, then `"channel": "   "`, then `"channel": null`. Expect the same 400 `VALIDATION_ERROR` each time.
4. Call `GET /api/incentives/v1/incentive-points/10000000-0000-4000-8000-000000000001/slab-configs/<slab_config_id>`. Expect the slabs from step 1, unchanged.
5. Send the base body to POST again, but without the `channel` key. Expect the same 400 `VALIDATION_ERROR` and message as PATCH. The channel check runs before the overlap check, so reusing `2026-12` is fine here.

**B. Channel sent on an incentive point that does not take one**

If `TR_STOCK_BY_PRODUCT` already has `requires_channel = true` (after SCRUM-538), switch it off for this test and switch it back at the end:

```sql
UPDATE incentive_point_metrics SET requires_channel = false
WHERE id = '10000000-0000-4000-8000-000000000006';
```

6. Create a config: `POST /api/incentives/v1/incentive-points/10000000-0000-4000-8000-000000000006/slab-configs` with `valid_from`/`valid_to` `2026-12` and a group `{ "salesperson_type": "TRADER", "level": 1, "slabs": [ { "band_order": 1, "operator": ">=", "value": 50, "points": 5 } ] }` (no `channel` key). Expect `201` and note the `slab_config_id`.
7. PATCH that config with `"is_config_updated": false, "is_slabs_updated": true` and the same group plus `"channel": "TRADER"`. Expect `400`, `error_code: "VALIDATION_ERROR"`, message `channel must not be provided for this incentive point`.
8. Repeat step 7 with `"channel": null`. Expect the same error: the key being present is enough.
9. If you ran the SQL above, revert it:

```sql
UPDATE incentive_point_metrics SET requires_channel = true
WHERE id = '10000000-0000-4000-8000-000000000006';
```

**C. Nothing else changed**

10. PATCH the config from step 1 with `"is_config_updated": true, "is_slabs_updated": false, "updated_valid_from": "2026-12", "updated_valid_to": "2026-12"` and no `groups`. Expect `200`: the channel is not checked when slabs are not being updated.
11. PATCH the config from step 1 with `"is_slabs_updated": true`, a valid `channel` (`CATERING`) and new slabs. Expect `200`, and the response groups show the new slabs.
12. Check every response above: `INVALID_CHANNEL` should never appear.

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

## Out of Scope

* Any other validation, check order, message or response shape change.

---

# Example B: SCRUM-567 (Task, every section of the newest template)

Edits: the AC self-check table is removed. The "Where" column with file and function names is removed from the first Context table (names go in the text, and only when needed); the Scope and Dev notes still name files where the dev needs the exact spot. The partner ID is replaced.

**Summary:** Backend - Add details.missing_or_invalid to every channel validation error (Slab, Ageing, Target APIs)

**Blocked by:** SCRUM-559

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

1. POST with the base group but no `channel` key. Expect `400`, `error_code: "VALIDATION_ERROR"`, message `channel is required for this incentive point`, `details.missing_or_invalid: ["groups[0].channel"]`.
2. Repeat with `"channel": null`, `""`, `"   "`, `123`, `true`, `[]`, `{}`. Expect the same each time.
3. Send two groups (`level` 1 and 2), where only the second has `"channel": 123`. Expect `details.missing_or_invalid: ["groups[1].channel"]`.
4. POST with the valid base group. Expect `201`. Note the `slab_config_id`.

**B. Slab PATCH** (the config from step 4, `"is_config_updated": false, "is_slabs_updated": true`)

5. Repeat steps 1–3 as PATCH bodies. Expect the same responses. `INVALID_CHANNEL` never appears.
6. PATCH with `"is_config_updated": true, "is_slabs_updated": false` and the same period (`updated_valid_from` / `updated_valid_to`). Expect `200`: the channel isn't checked.
7. `GET .../slab-configs/<slab_config_id>`. Expect the slabs from step 4, unchanged.

**C. Slab, channel not allowed** (`TR_STOCK_BY_PRODUCT`)

8. If SCRUM-538 has already flipped Trader metrics, switch it back for this test:

```sql
UPDATE incentive_point_metrics SET requires_channel = false WHERE id = '10000000-0000-4000-8000-000000000006';
```

9. POST with `{ "channel": "TRADER", "salesperson_type": "TRADER", "level": 1, "slabs": [ { "band_order": 1, "operator": ">=", "value": 50, "points": 5 } ] }`. Expect `400 VALIDATION_ERROR`, message `channel must not be provided for this incentive point`, `details.missing_or_invalid: ["groups[0].channel"]`. Repeat with `"channel": null` and expect the same; the key being present is enough.
10. POST the same group without `channel`. Expect `201`. PATCH that config (`"is_slabs_updated": true`) with `"channel": "TRADER"`. Expect the same error as step 9.
11. If you ran step 8, revert it:

```sql
UPDATE incentive_point_metrics SET requires_channel = true WHERE id = '10000000-0000-4000-8000-000000000006';
```

**D. Ageing (regression; should already pass)**

12. `POST /api/incentives/v1/ageing-deduction-configs` (free period) with `channels[0].channel` set to `123`, `null`, `""`, missing, and a 101-character string. Expect `400 VALIDATION_ERROR`, message `Request validation failed`, `details.missing_or_invalid: ["channels[0].channel"]` each time.

**E. Targets** (T1, current month)

13. `POST /api/target/v1/target-type/<T1_ID>/target-value` with `{ "start_date": "2026-10-01", "end_date": "2026-10-31", "target_value": 1000, "data": { "salesperson_id": "<SP_ID>", "salesperson_name": "QA SP", "channel": 123 } }`. Expect `400 VALIDATION_ERROR`, message `Request body validation failed`, `details.missing_or_invalid: ["channel"]` (not 500).
14. Repeat step 13 with `true`, `{}` and `["HORE"]`. Expect the same.
15. Repeat step 13 with no `channel`, then `""`. Expect `400 MISSING_REQUIRED_DIMENSIONS` with `details.missing_fields: ["channel"]` (unchanged).
16. Create a valid T1 target with `"channel": "QSR"`. Expect `201`. PATCH it (`/target-value/<id>`) with the same body and `"channel": 123`. Expect the step 13 error. Then check the original row is still `ACTIVE`:

```sql
SELECT status FROM target_sales_volume_all_customers WHERE id = '<id>';
```

17. Repeat step 13 on `<T2_ID>` with another salesperson. Expect the same.
18. On the `target_call_plan` type, POST a valid body for that type (its own `salesperson_type_id` / `salesperson_type_name`) plus `"channel": 123` inside `data`. Expect the same result as without `channel` (it's ignored).
19. Nothing was saved by the failed calls:

```sql
SELECT count(*) FROM target_sales_volume_all_customers
WHERE salesperson_id = '<SP_ID>' AND created_at > now() - interval '1 hour';
```

Expect only the row(s) from step 16.

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

| HTTP | error_code | message | details | Trigger |
| --- | --- | --- | --- | --- |
| 400 | `VALIDATION_ERROR` | channel is required for this incentive point | `missing_or_invalid: ["groups[<i>].channel"]` | AC 1 |
| 400 | `VALIDATION_ERROR` | channel must not be provided for this incentive point | `missing_or_invalid: ["groups[<i>].channel"]` | AC 2 |
| 400 | `VALIDATION_ERROR` | Request validation failed | `missing_or_invalid: ["channels[<i>].channel"]` | AC 4 (unchanged) |
| 400 | `VALIDATION_ERROR` | Request body validation failed | `missing_or_invalid: ["channel"]` | AC 5 |
| 400 | `MISSING_REQUIRED_DIMENSIONS` | Missing required dimension fields for this target type | `missing_fields`, `target_type`, `table_name` | AC 6 (unchanged) |

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
