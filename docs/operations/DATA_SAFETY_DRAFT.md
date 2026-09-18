# Google Play Data Safety Section Draft

Use these answers when completing the **Data Safety** questionnaire in Google Play Console.

---

## 1. Data Collection and Security Overview

- **Does your app collect or share any of the required user data types?**
  - **Optional only** (optional response reports are collected only when the user reviews and sends the prepared email; no background telemetry or analytics are collected).
- **Is all of the user data collected by your app encrypted in transit?**
  - **Yes** (reports use the user's email provider in transit with TLS).
- **Do you provide a way for users to request that their data be deleted?**
  - **Yes** (In-app "Delete All Local Data" feature in Settings attempts to purge conversations, encryption keys, downloaded models, creations, profile preferences, Skills, and onboarding state, returning detailed results).

---

## 2. Data Types Breakdown

### A. Location
- **Collected**: No.
- **Shared**: No.

### B. Personal Info
- **Collected**: **Optional** (only contact details voluntarily entered in an AI response report).
- **Shared**: No.
- **Purposes**: Developer Communications, App Functionality, Fraud Prevention & Safety.
- Profile preferences and custom instructions entered for on-device personalization remain in app-private local storage and are not collected by the developer.

### C. App Activity
- **Collected**: No.
- **Shared**: No.

### D. App Info & Performance
- **Collected**: No.
- **Shared**: No.

### E. User-generated Content
- **Data Type**: Optional AI response report and, only with a separate opt-in, its associated prompt.
- **Collected**: **Yes**, only after the user reviews and sends the report from their email app.
- **Shared**: No.
- **Required or Optional**: Optional.
- **Purposes**: Developer Communications, App Functionality, Fraud Prevention & Safety.

### F. Device or Other IDs
- **Collected**: No.
- **Shared**: No.

### G. Audio
- **Data Type**: Voice or sound recordings, used only for voice input (Android `RECORD_AUDIO`).
- **Collected**: No.
- **Shared**: No.
- **Required or Optional**: Optional.
- **Purposes**: App Functionality.
- Voice input audio is captured from the device microphone to produce a
  transcript and is not recorded, stored, collected, or shared by the developer.
  Transcription is performed by the device's platform speech-recognition
  service; the resulting transcript is processed on device like typed input.

### H. Notifications and Foreground Service (Model Download)
- **Collected**: No.
- **Shared**: No.
- FinnAI declares `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_DATA_SYNC`, and
  `POST_NOTIFICATIONS`. A model download runs in a foreground `dataSync` service
  and posts a local progress notification; the notification reports download
  progress only, carries no user data, and nothing is collected or shared.

### I. Automatic Web Search (Search Query and Page Requests)
- **Data Type**: Search query and retrieved-page requests. No user data type is
  collected or stored by the developer.
- **Collected**: No by the developer. When a turn uses automatic web search, the
  latest request is sent over HTTPS to DuckDuckGo (`api.duckduckgo.com` and
  `html.duckduckgo.com`) and Wikipedia (`en.wikipedia.org`) for transient
  processing.
- **Shared**: Reconcile in the Play Console questionnaire before submission
  (see §4). The query is sent to third-party search providers, and opening a
  retrieved source fetches that page from its own third-party HTTPS host, which
  sees the page URL and ordinary network metadata.
- **Purposes**: App Functionality.

---

## 3. Privacy Policy URL
```text
https://finn-org.vercel.app/privacy
```
*(Provide hosted HTTPS URL to Google Play Console prior to production submission).*

## 4. Play Console Declarations That Must Match

- Declare that FinnAI does **NOT** contain ads.
- Declare that FinnAI does **NOT** use Advertising ID.
- Treat optional AI response reports as collected user-generated content only
  when the user explicitly submits them.
- Conversation history remains on-device. Automatic web search sends only the
  latest request to the configured search provider for transient processing;
  opening a retrieved source additionally fetches that third-party page from its
  own host over HTTPS. Reconcile these features with the Play Console's current
  collection guidance before submission.
- Reconcile the target-audience answers with the child-directed request tags before publishing.
