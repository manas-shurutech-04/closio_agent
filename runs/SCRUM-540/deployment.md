# SCRUM-540 — deployment
Card: [SCRUM-540: Backend — GET Trader Stock Days Multiplier Configs (WS1 + WS2)](https://productclosio.atlassian.net/browse/SCRUM-540) · Jira comment: 15476

## What this card adds
A new API that lists a partner's trader stock days multiplier configs: how many days count as the trader's stock period, from which date to which date, and whether the config is active. It can be filtered to only active or only inactive configs.

## Deploy order
1. nodejs-ws2targetsalesincentive (target sales WS2) — MR !248, merge commit 1e8fea4f
2. nodejs-ws1closio (WS1) — MR !561, merge commit 65712e8b

## nodejs-ws2targetsalesincentive
- MR: https://jcvs.japfacomfeed.co.id/target-sales/backend/nodejs-ws2targetsalesincentive/-/merge_requests/248
- Database migration to run: 20261017100000-create-trader-stock-days-multiplier-configs.js
  - What it does: creates a new table, trader_stock_days_multiplier_configs, to hold the configs. It also turns on a database add-on (btree_gist) that stops one partner from having two active configs with overlapping dates. The database user must be allowed to turn on that add-on; if not, ask the database admin to turn it on first.
  - To undo it: undo this one migration; the table is removed.
- Database seeder to run: 20261017100001-seed-trader-stock-days-multiplier-configs.js
  - Run this seeder on its own, not all the seeders together (running all of them repeats older seeders, and the first of those fails).
  - What it does: adds one default config: partner e3d8f926-a1bf-4890-9524-cc2d610152f9, 30 days, from 1 October 2026 to 31 October 2026, active. If that partner already has an active config covering October, it adds nothing, so running it twice is safe.
  - To undo it: undo this one seeder; only that default config is removed.
- New settings in the .env file: none
- After deploying: nothing more

## nodejs-ws1closio
- MR: https://jcvs.japfacomfeed.co.id/closio/backend/nodejs-ws1closio/-/merge_requests/561
- Database migrations or seeders: none
- New settings in the .env file: none
- After deploying: nothing more

## The API
**List trader stock days multiplier configs** (GET)
- Through WS1 (logged in to Closio; the configs of the logged-in user's partner):
  https://dev-closio-ws1-apiprivate.japfacomfeed.co.id/api/incentives/v1/trader-stock-days-multiplier-configs
- Straight to WS2 (needs the service client ID and secret, and the partner ID in the X-Partner-Id header):
  https://dev-target-sales-ws2-apiprivate.japfacomfeed.co.id/api/incentives/v1/trader-stock-days-multiplier-configs
- Filter (optional): add ?status=active or ?status=inactive. Any other filter, or any other value, is refused with an error.
- What comes back: a list of configs, newest first. Each config shows:

| Field | What it means | Example from dev |
|---|---|---|
| id | the config's ID | 1b094668-65ba-4f7e-854e-474ee9b5e5c7 |
| valid_from | first day the config applies | 2026-10-01 |
| valid_to | last day it applies (empty: no end date) | 2026-10-31 |
| multiplier_days | the number of days | 30 |
| status | active or inactive | active |
| created_by | who created it (empty for the default config) | empty |
| created_by_name | that person's name | empty |
| created_at | when it was created | 2026-10-17 17:53 UTC |

- A partner with no configs gets an empty list.
- Checked on dev on 2026-10-19: every acceptance criterion passed.

## Try it on dev (curl)
Connect the VPN first. Replace the parts in `<…>` with your own values; never paste a password or secret into Jira or a chat.

**1. Log in to WS1 on dev** (saves the session cookie in `closio-cookies.txt`). The password is sent base64-encoded, as the web app does: get it with `printf '%s' '<your password>' | base64`.
```
curl -X POST 'https://dev-closio-ws1-apiprivate.japfacomfeed.co.id/api/v1/login' \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -H 'X-Secure-Transmission-Type: x' \
  -H 'X-Application-Version: 1.0.0+1' \
  -c closio-cookies.txt \
  --data '{"userid":"<your Closio user ID>","password":"<your password, base64-encoded>","napp_pk":4,"client_type":"web"}'
```

**2. List the configs through WS1** (the logged-in user's partner)
```
curl 'https://dev-closio-ws1-apiprivate.japfacomfeed.co.id/api/incentives/v1/trader-stock-days-multiplier-configs' \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -H 'X-Secure-Transmission-Type: x' \
  -H 'X-Application-Version: 1.0.0+1' \
  -b closio-cookies.txt
```
Only active ones: add `?status=active` to the address (`?status=inactive` for inactive ones).

**3. List the configs straight from WS2** (the service client ID and secret are the ones WS1 uses for target sales; ask the team lead)
```
curl 'https://dev-target-sales-ws2-apiprivate.japfacomfeed.co.id/api/incentives/v1/trader-stock-days-multiplier-configs' \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -H 'x-client-id: <client ID>' \
  -H 'x-client-secret: <client secret>' \
  -H 'X-Partner-Id: e3d8f926-a1bf-4890-9524-cc2d610152f9'
```

**4. Log out:** delete `closio-cookies.txt`.

## Special instructions
none
