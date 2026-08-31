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
  reconcile this feature with the Play Console's current collection guidance
  before submission.
- Reconcile the target-audience answers with the child-directed request tags before publishing.
