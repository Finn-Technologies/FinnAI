# FinnAI In-App AI Response Reporting Backend Specification

## Overview
FinnAI includes an in-app reporting flow for flagged AI assistant outputs to comply with Google Play Store policies for generative AI apps. Users can report responses directly within the application.

## API Endpoint Specification

- **Route**: `POST /v1/reports`
- **Protocol**: HTTPS required in production
- **Header**: `Content-Type: application/json`
- **Authentication**: Optional Bearer / API token when `FINN_REPORT_TOKEN` is supplied at build time.

### Request Body Schema
```json
{
  "reportId": "string",
  "category": "harmfulOrDangerous | hateOrHarassment | sexualContent | childSafety | selfHarm | illegalOrDeceptive | falseOrMisleading | other",
  "categoryLabel": "string",
  "assistantResponse": "string",
  "timestamp": "ISO-8601 string",
  "appVersion": "string",
  "modelTier": "string",
  "userPrompt": "string (optional, included only with explicit user opt-in)",
  "additionalDetails": "string (optional)"
}
```

### Privacy & Data Safety
- No Advertising ID, Android ID, hardware serial, or user account identity is attached to report payloads.
- IP addresses are processed in memory for rate limiting (max 10 requests / hour per IP) and are not stored in report KV/database records.

## Deployment Guide

### Cloudflare Workers Deployment
1. Install Wrangler CLI: `npm install -g wrangler`
2. Authenticate: `wrangler login`
3. Create KV Namespace: `wrangler kv:namespace create REPORTS_KV`
4. Deploy worker: `wrangler deploy`
5. Configure the production endpoint URL in Flutter build:
   ```bash
   flutter build appbundle --release --dart-define=FINN_REPORT_ENDPOINT="https://reports.finnai.app/v1/reports"
   ```

## Remaining Manual Action
Deploy `reporting-service/` to your cloud provider (Cloudflare Workers, AWS Lambda, Firebase Functions, or Vercel) and provide `FINN_REPORT_ENDPOINT` during release compilation.
