# Privacy Policy for FinnAI

**Last Updated: July 25, 2026**

FinnAI ("we", "our", or "us") is committed to protecting your privacy. This Privacy Policy explains how data is handled when you use the FinnAI mobile application for Android.

## 1. On-Device AI Processing & Privacy First Design
FinnAI is designed as an on-device AI assistant. All prompts, user messages, and AI-generated responses are processed locally on your Android device using mmap-backed GGUF inference engines.

- **No Remote AI Servers**: Your AI prompts and conversations are NOT sent to FinnAI or third-party AI cloud API providers.
- **Encrypted Local Storage**: Your saved conversation history is stored strictly on your local device with authenticated AES-256-CTR-HMAC-SHA256 encryption. Encryption keys are managed using the Android Keystore system.

## 2. Network Usage & Third-Party Services
FinnAI uses network access exclusively for the following specific purposes:

### A. Model Downloads
When you download or update an AI model, the application connects to public model repositories (such as Hugging Face) over HTTPS to fetch `.gguf` model files. Model downloads contain open-source weights and do not transmit user data.

### B. Advertising & Google UMP Consent
FinnAI uses Google AdMob to display advertisements when allowed.
- Google User Messaging Platform (UMP) requests and manages privacy consent in accordance with applicable laws (e.g., GDPR, CCPA).
- AdMob collects device identifiers and technical metrics to serve advertisements when permitted by user consent.
- You can change your advertising privacy choices at any time from the app Settings under **Privacy choices**.

### C. Optional In-App AI Response Reporting
If you explicitly choose to report an AI response via the in-app "Report" feature:
- Only the reported response, selected category, app version, and optional user details are submitted over HTTPS.
- Your prompt is included ONLY if you explicitly check the opt-in box.
- Reports are processed securely and do NOT include persistent advertising IDs, device serials, or location.

## 3. Data Retention & User Controls
You retain full control over your local data at any time:
- **Delete All Local Data**: In the app Settings, you can tap **Delete all local data** to permanently erase all conversation history, encryption keys, downloaded AI model files, and cached application state.
- **Purge AI Memory**: Unloads AI models from device RAM immediately.

## 4. Children's Privacy
FinnAI does not knowingly collect personal information from children under the age of 13.

## 5. Contact Us
If you have questions about this Privacy Policy or data safety, contact us at:
- **Email**: `support@finnai.app` (or configure via `FINN_SUPPORT_EMAIL`)
