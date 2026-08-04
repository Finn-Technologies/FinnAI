# Google Play Data Safety Section Draft

Use these answers when completing the **Data Safety** questionnaire in Google Play Console.

---

## 1. Data Collection and Security Overview

- **Does your app collect or share any of the required user data types?**
  - **Yes** (Google Mobile Ads collects and shares data for ads, analytics, and fraud prevention; optional reports are collected only when the user reviews and sends the prepared email).
- **Is all of the user data collected by your app encrypted in transit?**
  - **Yes** (reports use the user's email provider in transit, and Google Mobile Ads encrypts its data in transit using TLS).
- **Do you provide a way for users to request that their data be deleted?**
  - **Yes** (In-app "Delete All Local Data" feature in Settings attempts to purge conversations, encryption keys, downloaded models, creations, profile preferences, Skills, and onboarding state, returning detailed results).

---

## 2. Data Types Breakdown

### A. Location
- **Data Type**: Approximate location inferred from IP address.
- **Collected**: **Yes** (Google Mobile Ads).
- **Shared**: **Yes** (Google).
- **Purposes**: Advertising or Marketing, Analytics, Fraud Prevention/Security/Compliance.

### B. Personal Info
- **Collected**: **Optional** (only contact details voluntarily entered in an AI response report).
- **Shared**: No.
- **Purposes**: Developer Communications, App Functionality, Fraud Prevention & Safety.
- Profile preferences and custom instructions entered for on-device personalization remain in app-private local storage and are not collected by the developer.

### C. App Activity
- **Data Type**: App interactions.
- **Collected / Shared**: **Yes** (Google Mobile Ads automatically processes interactions including app launches, taps, and ad/video views).
- **Purposes**: Advertising or Marketing, Analytics, Fraud Prevention/Security/Compliance.

### D. App Info & Performance
- **Data Type**: Diagnostics and performance data.
- **Collected / Shared**: **Yes** (Google Mobile Ads may process app/SDK launch time, hang rate, and energy-use diagnostics).
- **Purposes**: Advertising or Marketing, Analytics, Fraud Prevention/Security/Compliance.

### E. User-generated Content
- **Data Type**: Optional AI response report and, only with a separate opt-in, its associated prompt.
- **Collected**: **Yes**, only after the user reviews and sends the report from their email app.
- **Shared**: No.
- **Required or Optional**: Optional.
- **Purposes**: Developer Communications, App Functionality, Fraud Prevention & Safety.

### F. Device or Other IDs
- **Data Type**: Device or other IDs (including advertising ID and app set ID where available).
- **Collected**: **Yes** (Google Mobile Ads).
- **Shared**: **Yes** (Shared with Google AdMob).
- **Purposes**: Advertising or Marketing, Analytics, Fraud Prevention/Security/Compliance.

Review the live Google Mobile Ads disclosure before every Play submission because SDK behavior and the Play questionnaire can change:
`https://developers.google.com/admob/android/privacy/play-data-disclosure`

This draft was last reconciled on July 28, 2026 against
`google_mobile_ads 9.0.0`. The publisher must review every dependency and the
live disclosure again immediately before answering in Play Console.

---

## 3. Privacy Policy URL
```text
https://finn-org.vercel.app/privacy
```
*(Provide hosted HTTPS URL to Google Play Console prior to production submission).*

## 4. Play Console Declarations That Must Match

- Declare that FinnAI contains ads.
- Declare Advertising ID use for advertising, analytics, and fraud prevention
  as applicable to the configured Google Mobile Ads products.
- Treat optional AI response reports as collected user-generated content only
  when the user explicitly submits them.
- Conversation history remains on-device. Automatic web search sends only the
  latest request to the configured search provider for transient processing;
  reconcile this feature with the Play Console's current collection guidance
  before submission.
- Reconcile the target-audience answers with the child-directed and
  under-age-of-consent request tags before publishing.
