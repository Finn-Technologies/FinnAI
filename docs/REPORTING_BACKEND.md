# Finn AI In-App Response Reporting Backend

> Legacy/optional design. The production app now prepares user-reviewable
> email reports addressed to `finn_org@proton.me`; its Report action does not
> call this endpoint.

## Overview
The canonical backend is maintained in the separate public
[`Finn-Technologies/landing-page`](https://github.com/Finn-Technologies/landing-page)
repository and deployed with that site on Vercel. Backend source must not be
duplicated in the private Flutter repository.

---

## API Endpoint Specification

- **Route**: `POST /v1/reports`
- **Protocol**: HTTPS required in production
- **Header**: `Content-Type: application/json`
- **Health check**: `GET /health` returns HTTP 200 with `{"status":"ok"}`
  only when both required production bindings are configured.

### Request Body Schema
```json
{
  "reportId": "string (alphanumeric/underscores/dashes, max 100 chars)",
  "category": "harmfulOrDangerous | hateOrHarassment | sexualContent | childSafety | selfHarm | illegalOrDeceptive | falseOrMisleading | spamOrScam | other",
  "assistantResponse": "string (max 4000 chars)",
  "timestamp": "ISO-8601 string",
  "appVersion": "string (max 50 chars)",
  "modelTier": "string (max 100 chars)",
  "userPrompt": "string (optional, max 2000 chars)",
  "additionalDetails": "string (optional, max 1000 chars)"
}
```

### Strict Server Validation & Unknown Field Rejection
- Unknown fields are strictly rejected with HTTP 400 (`{"error": "Unknown field '...' in report payload"}`).
- Missing required fields or invalid timestamps return HTTP 400.
- Missing Upstash Redis credentials or `RATE_LIMIT_SALT` returns HTTP 503.

### Data Retention & Privacy
- **Retention TTL**: All `report:*` records stored in Upstash Redis expire
  automatically after **30 days** (`2592000` seconds).
- No Advertising ID, Android ID, hardware serial, or user account identity is attached to report payloads.
- Client IP addresses are hashed with `RATE_LIMIT_SALT` for hourly rate limiting (max 10 requests / hour per IP) and are **never** persisted to storage.

---

## Vercel Production Configuration

Connect an Upstash Redis database to the landing-page Vercel project and set:

```text
UPSTASH_REDIS_REST_URL
UPSTASH_REDIS_REST_TOKEN
RATE_LIMIT_SALT
```

The deployed routes are:

- `POST https://finn-org.vercel.app/v1/reports`
- `GET https://finn-org.vercel.app/health`

---

## Operational Status (Legacy / Test-Only)

The `/health` endpoint flow described above is **legacy and test-only**: it is
part of the optional landing-page backend design and is not exercised by the
release builder.

`tool/build_play_release.sh` does **not** query `/health`. Before building the
publishable AAB it only verifies that the three hosted public pages return
HTTP 200 over HTTPS:

- `FINN_PRIVACY_POLICY_URL` (default `https://finn-org.vercel.app/privacy`)
- `FINN_TERMS_URL` (default `https://finn-org.vercel.app/terms`)
- `FINN_SUPPORT_URL` (default `https://finn-org.vercel.app/support`)

The production app itself prepares user-reviewable email reports addressed to
`finn_org@proton.me` and never calls the `POST /v1/reports` endpoint.
