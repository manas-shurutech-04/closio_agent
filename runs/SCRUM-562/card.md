# SCRUM-562 — Validation error on valid_to will highlight valid_from field.

_Bug · To Do · Read on 2026-10-21_

![](blob:https://media.staging.atl-paas.net/?type=file&localId=73c0eef79387&id=cd6f1b2c-0c16-4d1b-8d5b-507b883114f9&&collection=&height=745&occurrenceKey=null&width=1706&__contextId=null&__displayType=null&__external=false&__fileMimeType=null&__fileName=null&__fileSize=null&__mediaTraceId=null&url=null)

## Explained at pick-up

- Screenshot-only Bug card (no Context/ACs/QA); proceeding and keeping the gaps (decision 2).
- Screenshot shows: API returns `error_code: VALIDATION_ERROR`, `details.missing_or_invalid: ["valid_to"]`, `message: "Request validation failed"`; the message is rendered under the Berlaku sejak (valid_from) field instead of Berlaku sampai (valid_to).
- Fix is conditional on investigation during planning: whether the frontend maps each field-error to its matching field, and whether a valid_to-only error is reproducible on dev (decision 3).
