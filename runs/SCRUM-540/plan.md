# SCRUM-540 — plan

Approved by the user on 2026-10-17

Memory applied: none

The ruleset file `backend/story-implementation-workflow.md` isn't in closio-agent yet (D26: to be refined), so the plan follows each repo's closest existing module (Express 5).

## Summary

Add `GET /api/incentives/v1/trader-stock-days-multiplier-configs`, which returns a partner's Trader stock days multiplier configs, optionally filtered by `status`. The call goes Closio → WS1 (session, partner and user) → WS2 (S2S auth, partner check, query). This card also creates the `trader_stock_days_multiplier_configs` table, its model and a default config seeder in WS2 (SCRUM-539's scope).

## Acceptance criteria

As in the card:

* AC1: all of the partner's configs.
* AC2: `?status=active|inactive` filter.
* AC3: empty `configs: []`.
* AC4: the 8 response fields.
* AC5: WS1 forwards with `x-client-id`, `x-client-secret`, `X-Partner-Id`, `X-User-Id`, `X-User-Name`.
* AC6: 401 `MISSING_CLIENT_CREDENTIALS`.
* AC7: 401 `UNKNOWN_CLIENT`.
* AC8: 401 `INVALID_CLIENT_AUTH`.
* AC9: 400 `PARTNER_ID_MISSING`.
* AC10: 400 `VALIDATION_ERROR` with `["X-Partner-Id"]`.

Table: SCRUM-539's AC1–AC3 (migrate, undo, model registered).

## Decided before planning

0. This card also builds the SCRUM-539 table and model in WS2.
1. `updated_at` is nullable with no default.
2. A seeder adds one default config: partner `e3d8f926-a1bf-4890-9524-cc2d610152f9`, `multiplier_days` 30, period = the current month (UTC, when the seeder runs).
3. `multiplier_days` is returned as a number.
4. No business check.
5. No pagination.
6. An invalid `status` gives 400 `VALIDATION_ERROR`, `status must be one of: active, inactive`. New constant: `VALID_TRADER_STOCK_DAYS_MULTIPLIER_CONFIG_STATUSES`.
7. Order: `created_at DESC`.
8. Exactly the 8 fields of AC4.
9. `created_at` uses the code's default date format (`….000Z`).
10. A DB failure gives 500 `INTERNAL_ERROR`, `could not fetch trader stock days multiplier configs`.
11. WS1 gets a route, a controller and a schema file, no service file.
12. Routes are registered in `src/routes/incentives/index.js` in both repos.
13. WS1 returns `PARTNER_ID_MISSING` with the message `X-Partner-Id header is required`.
14. WS1 checks the WS2 success response; otherwise it returns 500 `INTERNAL_SERVER_ERROR`.
15. WS1 allows only the `status` query parameter.
16. File names as listed under Changes.
17. Tests in WS2 only.

(Full answers: `card.md`, section "Decided before planning".)

## Changes

### 1. nodejs-ws2targetsalesincentive (WS2) first

**a. Migration** `src/migrations/<YYYYMMDDHHMMSS>-create-trader-stock-days-multiplier-configs.js`, copying `20261004100000-create-ar-ageing-deduction-configs.js`:

* `CREATE EXTENSION IF NOT EXISTS btree_gist`.
* `createTable` with SCRUM-539's columns: `id` UUID PK `gen_random_uuid()`, `partner_id` UUID not null, `multiplier_days` `DECIMAL(8,2)` not null default 30, `valid_from` DATEONLY not null, `valid_to` DATEONLY nullable, `status` `STRING(20)` not null default `'active'`, `created_by`/`updated_by` UUID nullable, `created_by_name`/`updated_by_name` `STRING(255)` nullable, `created_at` not null default `NOW()`, `updated_at` nullable with no default (answer 1).
* `setTableOwner(queryInterface, 'trader_stock_days_multiplier_configs')`.
* Constraints:
    * `chk_tsdmc_multiplier` (`multiplier_days > 0`)
    * `chk_tsdmc_period` (`valid_to IS NULL OR valid_to >= valid_from`)
    * `chk_tsdmc_status` (`status IN ('active','inactive')`)
    * partial index `idx_tsdmc_lookup` on `(partner_id, valid_from, valid_to) WHERE status = 'active'`
    * `excl_tsdmc_no_active_overlap` (gist on `partner_id WITH =`, `daterange(valid_from, valid_to, '[]') WITH &&`, `WHERE (status = 'active')`)
* `down`: `dropTable('trader_stock_days_multiplier_configs')`.

**b. Model** `src/models/incentives/TraderStockDaysMultiplierConfig.js`, copying `ArAgeingDeductionConfig.js`:

* `tableName: 'trader_stock_days_multiplier_configs'`, `underscored: true`, `timestamps: false`.
* `valid_to` allows null, `status` validated as `isIn [['active','inactive']]`.
* Registered in `src/models/incentives/index.js`: require it and add it to `models`.

**c. Seeder** `src/seeders/<YYYYMMDDHHMMSS>-seed-trader-stock-days-multiplier-configs.js`, copying `20261002090001-seed-ar-ageing-buckets.js` (a transaction and a raw query with replacements):

* The period is worked out when it runs: the first and last day of the current UTC month.
* `INSERT … SELECT … WHERE NOT EXISTS` an active config for that partner overlapping that period. Running it twice is safe, and it never hits the overlap constraint.
* `down` deletes that partner's seeded row: empty `created_by`, `multiplier_days` 30, and a period of exactly one month (first to last day of the same month).

**d. Constant** in `src/constants/appConstants.js`: add `VALID_TRADER_STOCK_DAYS_MULTIPLIER_CONFIG_STATUSES = ['active', 'inactive']` next to `VALID_AGEING_DEDUCTION_CONFIG_STATUSES`, and export it.

**e. Service** `src/services/incentives/traderStockDaysMultiplierConfigService.js`, with `getTraderStockDaysMultiplierConfigs({ partnerId, status })`:

* `findAll` where `partner_id` (+ `status` if given), `order [['created_at', 'DESC']]`.
* Maps each row to the 8 fields, with `multiplier_days: Number(row.multiplier_days)`.
* Returns `{ configs }`.
* On error: an error that already has an `error_code` is thrown again as it is. Otherwise it throws 500 `INTERNAL_ERROR` `could not fetch trader stock days multiplier configs` with the same `details` (`message`, `name`, `pg_message`, `pg_code`) as `getAgeingDeductionConfigs`.

**f. Controller** `src/controllers/incentives/traderStockDaysMultiplierConfigController.js`, with `getTraderStockDaysMultiplierConfigs`. The checks run in the order of `getAgeingDeductionConfigs`:

1. No `X-Partner-Id` → 400 `PARTNER_ID_MISSING` `X-Partner-Id header is required.`
2. Not a UUID (`isValidUuid`) → 400 `VALIDATION_ERROR` `Request validation failed`, `details.missing_or_invalid: ['X-Partner-Id']`.
3. `status` given and not in the constant → 400 `VALIDATION_ERROR` `status must be one of: active, inactive`.
4. Service call → 200 `{ status: 'success', data }`. Errors go through `next(createError(err, err.status || 500))`.

**g. Route** `src/routes/incentives/traderStockDaysMultiplierConfigRoutes.js`: `router.get('/v1/trader-stock-days-multiplier-configs', …)`. It's mounted in `src/routes/incentives/index.js` with `router.use('/incentives', …)`, after `verifyClientAuth`, so AC6–AC8 come from the existing middleware.

### 2. nodejs-ws1closio (WS1)

**a. Schema** `src/schemas/v1/incentives/getTraderStockDaysMultiplierConfigs.js`, copying `getAgeingDeductionConfigs.js`:

* `queryParameter`: only `status` (string), `additionalProperties: false`, with the error message `invalid schema`.
* The 200 response describes `status` plus `data.configs[]` with the 8 fields; `multiplier_days` is a number and `valid_to` is a string or null. No `pagination`.
* The 400, 401 and 500 response blocks are the same as the sibling's.

**b. Controller** `src/controllers/v1/incentives/incentiveTraderStockDaysMultiplierConfigController.js`, with `getTraderStockDaysMultiplierConfigs`, copying `getAgeingDeductionConfigOptions`:

1. The partner comes from `req.session.closioV1Data.partnerId`. If it's missing → 400 `PARTNER_ID_MISSING` `X-Partner-Id header is required` (namespace `target-sales/messages`).
2. `apiWs2TargetSalesIncentive.get('/api/incentives/v1/trader-stock-days-multiplier-configs', { headers: buildWs2Headers({ req, partnerId, userId: cUserUuid, userName: cUserName }), params })`, where `params` holds `status` only if it was given. The axios instance already adds `X-Client-Id` and `X-Client-Secret` (AC5).
3. The success shape is checked (`status === 'success'`, `data`, `Array.isArray(data.configs)`); otherwise → 500 `INTERNAL_SERVER_ERROR` `Something went wrong. Please try again later.`
4. Otherwise it returns `res.validateResponse(…)`.
5. Errors are handled the same way as the sibling's `catch`:
    * a WS2 error status → the same status and body
    * axios or network error → 502 `UPSTREAM_REQUEST_FAILED` `Failed to reach Target Sales WS2`

**c. Route** `src/routes/incentives/incentiveTraderStockDaysMultiplierConfigRoutes.js`: `router.get('/v1/trader-stock-days-multiplier-configs', validateSchema(...), isAuthenticated, asyncHandler(...))`, mounted in `src/routes/incentives/index.js`.

**d. Locale files:** nothing new. Every message used is already in `locales/en|id/target-sales/messages.json`.

## Error codes

All of these already exist in the code. The only new message is answer 10.

**WS2:**

* 401 `MISSING_CLIENT_CREDENTIALS` `Missing client credentials`
* 401 `UNKNOWN_CLIENT` `Unknown client`
* 401 `INVALID_CLIENT_AUTH` `Invalid client credentials` (all three from `verifyClientAuth`)
* 400 `PARTNER_ID_MISSING` `X-Partner-Id header is required.`
* 400 `VALIDATION_ERROR` `Request validation failed` with `details.missing_or_invalid: ["X-Partner-Id"]`
* 400 `VALIDATION_ERROR` `status must be one of: active, inactive`
* 500 `INTERNAL_ERROR` `could not fetch trader stock days multiplier configs` (new message, approved)

**WS1:**

* 401 `SESSION_EXPIRED` and `INVALID_TOKEN` (from `isAuthenticated`)
* 400 `GENERAL_ERROR` `Invalid schema` (unknown query parameter)
* 400 `PARTNER_ID_MISSING` `X-Partner-Id header is required`
* 500 `INTERNAL_SERVER_ERROR` `Something went wrong. Please try again later.`
* 502 `UPSTREAM_REQUEST_FAILED` `Failed to reach Target Sales WS2`
* Any WS2 error is passed on with the same status and body.

## Migrations, seeders, queues

* **Migration:** one, `create-trader-stock-days-multiplier-configs`. It needs `btree_gist`, which the migration enables itself, and the `PG_USER_GROUP_WS2TARGETSALES` env var for `setTableOwner`, like every other create migration.
* **Seeder:** one, `seed-trader-stock-days-multiplier-configs`: the default config for partner `e3d8f926-a1bf-4890-9524-cc2d610152f9`, current month.
* **Queues:** none.

## Tests

WS2, committed:

* `test/unit/controller/incentives/traderStockDaysMultiplierConfigController.spec.js`: missing partner, non-UUID partner, invalid `status`, 200 with and without `status`, service error passed on.
* `test/unit/services/incentives/traderStockDaysMultiplierConfigService.spec.js` (sinon stubs on the model):
    * the `where` with and without `status`, and `order` `created_at DESC`
    * the 8 fields, with `multiplier_days` as a number
    * empty list → `configs: []`
    * DB error → 500 `INTERNAL_ERROR`
* `test/api/traderStockDaysMultiplierConfig.api.spec.js` (supertest):
    * AC6–AC8 (401s) and AC9–AC10 (400s)
    * invalid `status` → 400
    * AC1–AC4 (all configs, filter, empty, fields)
* Coverage stays at or above `--statements=80 --branches=70 --functions=80 --lines=80` (`npm run coverage:check`, also run by the husky hooks). Migrations are left out of coverage by `nyc`. Seeders and models have no tests today, the same as the siblings.

WS1: no tests, because the repo has no test setup.

## Out of scope

* Create, update and status change of trader stock days multiplier configs.
* Using the multiplier in the Trader stock-level calculation, and the missing-config gate.
* Business and role checks.
* Pagination.
* Any change to SCRUM-539 in Jira.
* Frontend work.
