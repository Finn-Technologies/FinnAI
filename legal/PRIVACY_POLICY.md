# Privacy Policy for FinnAI

**Last Updated: July 27, 2026**

FinnAI ("we", "our", or "us") is committed to protecting your privacy. This Privacy Policy explains how data is handled when you use the FinnAI mobile application for Android.

## 1. On-Device AI Processing & Privacy First Design
FinnAI is designed as an on-device AI assistant. All prompts, user messages, and AI-generated responses are processed locally on your Android device using mmap-backed GGUF inference engines.

- **No Remote AI Servers**: Your AI prompts and conversations are NOT sent to FinnAI or third-party AI cloud API providers.
- **Encrypted Local Storage**: Your saved conversation history is stored strictly on your local device with authenticated AES-256-GCM encryption. Encryption keys are managed using OS-enforced secure key storage (`FlutterSecureStorage`).
- **Other Local Features**: Creations, profile preferences, custom instructions, and Skills are stored in the app's private local storage. They are used only to provide the features you select and are not sent to an AI cloud service.

## 2. Network Usage & Third-Party Services
FinnAI uses network access exclusively for the following specific purposes:

### A. Model Downloads
When you download or update an AI model, the application connects to the configured model repository over HTTPS to fetch licensed `.gguf` model files. The request necessarily exposes ordinary network metadata, such as an IP address, to that host, but it does not include prompts or conversation content. FinnAI itself is proprietary software, not an open-source application.

### B. Advertising & Google UMP Consent
FinnAI uses Google AdMob to display advertisements when allowed.
- Google User Messaging Platform (UMP) requests and manages privacy consent in accordance with applicable laws (e.g., GDPR, CCPA).
- Google Mobile Ads may collect and share IP addresses (which can estimate general location), app interactions such as launches and taps, diagnostic and performance information, and device or account identifiers. Google uses these for advertising, analytics, and fraud prevention according to the user's choices and applicable law.
- You can change your advertising privacy choices at any time from the app Settings under **Privacy choices**.

### C. Optional In-App AI Response Reporting
If you explicitly choose to report an AI response via the in-app "Report" feature:
- Reports are submitted to `https://finn-org.vercel.app/v1/reports`.
- The reported response, selected category, timestamp, app version, model tier, and any additional details you enter are submitted over HTTPS.
- Your prompt is included ONLY if you explicitly check the prompt inclusion opt-in box.
- Reports are stored in a protected Upstash Redis database for up to 30 days. Upstash acts as a data processor for this service.
- FinnAI does not attach advertising IDs, Android IDs, or hardware serials to reports. The service uses a salted, one-way hash of the request IP only to enforce an hourly rate limit; neither the address nor its hash is stored with the report.

## 3. Data Retention & User Controls
You retain full control over your local data at any time:
- **Delete All Local Data**: In the app Settings, you can tap **Delete all local data** to attempt purging conversation history, encryption keys, downloaded AI model files, creations, profile preferences, Skills, and onboarding state. Any unpurged items are explicitly reported.
- **Purge AI Memory**: Unloads AI models from device RAM immediately.
- **Android backups disabled**: FinnAI disables Android application backup so private local AI data is not copied into platform backup archives.

## 4. Children's Privacy
FinnAI does not knowingly collect personal information from children under the age of 13.

## 5. Contact & Policy Availability
- **Public Policy URL**: `https://finn-org.vercel.app/privacy`
- **Support Contact**: `https://finn-org.vercel.app/support`
