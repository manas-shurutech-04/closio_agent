# SCRUM-540 — Backend — GET Trader Stock Days Multiplier Configs (WS1 + WS2)
_Type: Story · Status: To Do · Read from Jira on 2026-10-17_

## Objective

Implement `GET /api/incentives/v1/trader-stock-days-multiplier-configs` across both WS1 and WS2 to return Trader stock day multiplier configs for a partner. The day multiplier is used for Trader stock-level incentive point calculations.

Formula: `stock_level_days = stock_eom / billing_eom × multiplier_days`

## Implementation Scope

This is a frontend/admin API and must be implemented in both WS1 and WS2.

**Call flow:** Closio / FE → WS1 → ws2targetsales / incentive service

## WS1 Responsibilities

* Validate cookie/session.
* Fetch logged-in user details.
* Resolve `partner_id`, `user_id`, and `user_name`.
* Forward request to WS2 with S2S headers.
* Forward WS2 response to frontend.

**WS1 → WS2 headers:**

* `x-client-id`
* `x-client-secret`
* `X-Partner-Id`
* `X-User-Id`
* `X-User-Name`

## WS2 Responsibilities

* Validate `x-client-id` and `x-client-secret`.
* Validate `X-Partner-Id`.
* Apply partner-level access control.
* Execute the config query.
* Return response to WS1.

## Method & Path

`GET /api/incentives/v1/trader-stock-days-multiplier-configs`

## Query Parameters

| Parameter | Required | Description |
| --- | --- | --- |
| status | No | Filters configs by `active` / `inactive` status |

## Response (200)

```json
{
  "status": "success",
  "data": {
    "configs": [
      {
        "id": "<uuid>",
        "valid_from": "2026-06-01",
        "valid_to": null,
        "multiplier_days": 30,
        "status": "active",
        "created_by": "<uuid>",
        "created_by_name": "Admin User",
        "created_at": "2026-06-01T10:00:00Z"
      }
    ]
  }
}
```

## Acceptance Criteria

### AC1 — Returns all configs for the partner

**Given** a partner has multiple trader stock days multiplier configs (active and inactive)
**When** a valid request is made with no `status` filter
**Then** the response contains all configs for that partner.

### AC2 — Filters by status when provided

**Given** a partner has both active and inactive configs
**When** the request includes `?status=active`
**Then** only active configs are returned.
**When** the request includes `?status=inactive`
**Then** only inactive configs are returned.

### AC3 — Empty result when no configs exist

**Given** a partner has no trader stock days multiplier configs
**When** the endpoint is called
**Then** the response contains an empty `configs` array.

### AC4 — Response shape

**Given** a valid request is made
**When** the response returns
**Then** each config object contains `id`, `valid_from`, `valid_to`, `multiplier_days`, `status`, `created_by`, `created_by_name`, and `created_at`.

### AC5 — WS1 proxy forwards correctly

**Given** a valid session/cookie-authenticated request hits WS1
**When** WS1 resolves the user and partner context
**Then** WS1 forwards the request to WS2 with `x-client-id`, `x-client-secret`, `X-Partner-Id`, `X-User-Id`, `X-User-Name` headers, and returns the WS2 response to the frontend.

### AC6 — WS2 S2S auth — Missing client credentials

**Given** a request without `X-Client-Id` or `X-Client-Secret`
**When** it reaches WS2
**Then** it is rejected with HTTP 401 and error code `MISSING_CLIENT_CREDENTIALS`.

### AC7 — WS2 S2S auth — Unrecognized client

**Given** a request with an `X-Client-Id` not in `SERVICE_CREDENTIALS`
**When** it reaches WS2
**Then** it is rejected with HTTP 401 and error code `UNKNOWN_CLIENT`.

### AC8 — WS2 S2S auth — Wrong client secret

**Given** a request with a valid `X-Client-Id` but incorrect `X-Client-Secret`
**When** it reaches WS2
**Then** it is rejected with HTTP 401 and error code `INVALID_CLIENT_AUTH`.

### AC9 — WS2 — Missing partner ID

**Given** a request without `X-Partner-Id`
**When** it reaches WS2
**Then** it is rejected with HTTP 400 and error code `PARTNER_ID_MISSING` (message "X-Partner-Id header is required.").

### AC10 — WS2 — Invalid partner ID

**Given** a request with an `X-Partner-Id` that is not a valid UUID
**When** it reaches WS2
**Then** it is rejected with HTTP 400 and error code `VALIDATION_ERROR`, with `details.missing_or_invalid` = `["X-Partner-Id"]`.

## How QA can test this

_Setup_

1. Note partner P's id and log in to Closio as a user of P. Use this session for the WS1 calls.
2. Insert two configs for P and one for another partner Q:

```sql
INSERT INTO trader_stock_days_multiplier_configs (partner_id, multiplier_days, valid_from, valid_to, status) VALUES
('<P>', 30, '2026-01-01', '2026-06-30', 'inactive'),
('<P>', 31, '2026-07-01', NULL, 'active'),
('<Q>', 28, '2026-07-01', NULL, 'active');
```

_Steps_ (WS1 `GET /api/incentives/v1/trader-stock-days-multiplier-configs`)

3. No filter → P's 2 configs only. Each has `id`, `valid_from`, `valid_to` (null for the open-ended one), `multiplier_days`, `status`, `created_by`, `created_by_name`, `created_at`.
4. `?status=active` → 1 config. `?status=inactive` → 1 config.
5. Log in as a user of a partner with no configs → `configs: []`.
6. Call WS2 directly:

    * without `x-client-id` → 401 `MISSING_CLIENT_CREDENTIALS`
    * unknown client → 401 `UNKNOWN_CLIENT`
    * wrong secret → 401 `INVALID_CLIENT_AUTH`
    * without `X-Partner-Id` → 400 `PARTNER_ID_MISSING`
    * `X-Partner-Id: abc` → 400 `VALIDATION_ERROR`
    

_Clean up:_ `DELETE FROM trader_stock_days_multiplier_configs WHERE partner_id IN ('<P>','<Q>');`

## Dependencies / Preconditions

* SCRUM-539 — `trader_stock_days_multiplier_configs` table and model must exist

## Files

**WS2 (nodejs-ws2targetsalesincentive):** Create route, controller, service files for `traderStockDaysMultiplierConfig`. Modify `src/routes/index.js`.

**WS1 (nodejs-ws1closio):** Create proxy route, controller, service files. Modify `src/routes/index.js`.

## Explained at pick-up

Explained by the user on 2026-10-17, in answer to the card check:

* `## Objective` is the card's Context.
* The AC headings (`### AC1 — …`) are fine as they are.
