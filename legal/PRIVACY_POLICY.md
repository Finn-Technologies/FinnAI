# Privacy Policy for FinnAI

**Last Updated: July 27, 2026**

FinnAI ("we", "our", or "us") is committed to protecting your privacy. This Privacy Policy explains how data is handled when you use the FinnAI mobile application for Android.

## 1. On-Device AI Processing & Privacy First Design
FinnAI is designed as an on-device AI assistant. AI-generated responses are processed locally on your Android device using mmap-backed GGUF inference engines. When automatic web search is used, the latest request is also used as described below.

- **No Remote AI Servers**: Your conversations are not sent to FinnAI or third-party AI cloud inference providers.
- **Encrypted Local Storage**: Your saved conversation history is stored strictly on your local device with authenticated AES-256-GCM encryption. Encryption keys are managed using OS-enforced secure key storage (`FlutterSecureStorage`).
- **Other Local Features**: Creations, profile preferences, custom instructions, and Skills are stored in the app's private local storage. They are used only to provide the features you select and are not sent to an AI cloud service.

## Automatic Web Search

FinnAI decides locally whether a request needs current internet information,
including news, recipes, explicit web lookups, and other time-sensitive
questions. When it searches, only the latest user request is sent over HTTPS
to the configured search provider. Conversation history, saved profile data,
custom instructions, and Skills are not included. Search requests expose the
query and ordinary network metadata such as the device IP address to the search
provider. Retrieved excerpts are processed by the on-device model, and FinnAI
shows the source links used. If search is unavailable, FinnAI falls back to a
local answer.

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
- Reports are prepared as emails addressed to `finn_org@proton.me`. Nothing is
  sent until you review the report and press Send in your email app.
- The reported response, selected category, timestamp, app version, model tier, and any additional details you enter are submitted over HTTPS.
- Your prompt is included ONLY if you explicitly check the prompt inclusion opt-in box.
- Sent reports are retained in the receiving Proton Mail mailbox according to
  FinnAI's support and deletion procedures.
- FinnAI does not attach advertising IDs, Android IDs, hardware serials, or
  hidden device identifiers to reports.

## 3. Data Retention & User Controls
You retain full control over your local data at any time:
- **Delete All Local Data**: In the app Settings, you can tap **Delete all local data** to attempt purging conversation history, encryption keys, downloaded AI model files, creations, profile preferences, Skills, and onboarding state. Any unpurged items are explicitly reported.
- **Purge AI Memory**: Unloads AI models from device RAM immediately.
- **Android backups disabled**: FinnAI disables Android application backup so private local AI data is not copied into platform backup archives.

## 4. Generative AI Disclosure

FinnAI includes generative AI features that run locally on your device. AI outputs may be inaccurate, incomplete, or outdated. Review important information before acting on AI responses.

Flag inappropriate AI outputs from within the app via the Report feature so we can review and improve safety.

We moderate generative AI content in accordance with Google Play's Generative AI policy. Prohibited content, policy violations, and misuse can be reported to `finn_org@proton.me`.

## 5. Children's Privacy
FinnAI is not directed to children under 13 and does not knowingly collect personal information from children under that age.

## 6. Contact & Policy Availability
- **Public Policy URL**: `https://finn-org.vercel.app/privacy`
- **Support Contact**: `https://finn-org.vercel.app/support`
- **Support Email**: `finn_org@proton.me`
