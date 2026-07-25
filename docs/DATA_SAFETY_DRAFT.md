# Google Play Data Safety Section Draft

Use these exact answers when completing the **Data Safety** questionnaire in Google Play Console.

---

## 1. Data Collection and Security Overview

- **Does your app collect or share any of the required user data types?**
  - **Yes** (App collects advertising IDs via Google Mobile Ads SDK / UMP consent SDK, and user-submitted reports if submitted).
- **Is all of the user data collected by your app encrypted in transit?**
  - **Yes** (All network traffic uses HTTPS/TLS 1.3).
- **Do you provide a way for users to request that their data be deleted?**
  - **Yes** (In-app "Delete All Local Data" button in Settings immediately purges all encrypted local databases, keys, models, and cache files).

---

## 2. Data Types Breakdown

### A. Location
- **Collected**: No.
- **Shared**: No.

### B. Personal Info
- **Collected**: No.
- **Shared**: No.

### C. App Activity & User Reports (App Info & Performance)
- **Data Type**: App Interactions / User Reports (Optional)
- **Collected**: **Yes** (Only when user explicitly taps "Report response" in chat).
- **Shared**: No (Sent directly to developer report endpoint).
- **Ephemeral**: No.
- **Required or Optional**: **Optional** (User-initiated).
- **Purposes**: Developer Communications, App Functionality, Fraud Prevention & Safety.

### D. Device or Other IDs
- **Data Type**: Device or other IDs (Advertising ID)
- **Collected**: **Yes** (Collected by Google Mobile Ads SDK for ad serving and consent management).
- **Shared**: **Yes** (Shared with Google AdMob).
- **Ephemeral**: Yes.
- **Required or Optional**: Required for ad-supported functionality.
- **Purposes**: Advertising or Marketing.

---

## 3. Privacy Policy URL
```text
https://abhiflex.github.io/finnai/legal/PRIVACY_POLICY.html
```
*(Replace with your live hosted GitHub Pages / domain URL before publishing).*
