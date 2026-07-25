# FinnAI In-App AI Response Reporting Backend Specification

## Overview
FinnAI includes an in-app reporting flow for flagged AI assistant outputs to comply with Google Play Store policies for generative AI apps.

---

## API Endpoint Specification

- **Route**: `POST /v1/reports`
- **Protocol**: HTTPS required in production
- **Header**: `Content-Type: application/json`

### Request Body Schema
```json
{
  "reportId": "string (alphanumeric/underscores/dashes, max 100 chars)",
  "category": "harmfulOrDangerous | hateOrHarassment | sexualContent | childSafety | selfHarm | illegalOrDeceptive | falseOrMisleading | other",
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
- Missing `REPORTS_KV` or `RATE_LIMIT_SALT` configuration returns HTTP 503.

### Data Retention & Privacy
- **Retention TTL**: All report records stored in `REPORTS_KV` expire automatically after **30 days** (`expirationTtl: 2592000` seconds).
- No Advertising ID, Android ID, hardware serial, or user account identity is attached to report payloads.
- Client IP addresses are hashed with `RATE_LIMIT_SALT` for hourly rate limiting (max 10 requests / hour per IP) and are **never** persisted to storage.

---

## Cloudflare Workers Deployment

1. Install Wrangler CLI: `npm install -g wrangler`
2. Authenticate: `wrangler login`
3. Create KV Namespace: `wrangler kv:namespace create REPORTS_KV`
4. Set Secret Salt: `wrangler secret put RATE_LIMIT_SALT`
5. Deploy worker: `wrangler deploy`
6. Configure the production endpoint URL during Flutter release compilation:
   ```bash
   flutter build appbundle --release \
     --dart-define=FINN_REPORT_ENDPOINT="https://reports.finnai.app/v1/reports"
   ```

---

## Operational Status
When no production reporting endpoint is deployed, reporting is marked `BLOCKED / NOT DEPLOYED` and the in-app dialog informs the user that reporting is currently unconfigured.
