# Privacy Policy for FinnAI

**Last Updated: October 3, 2026**

FinnAI ("we", "our", or "us") is committed to protecting your privacy. This Privacy Policy explains how data is handled when you use the FinnAI mobile application for Android.

## 1. On-Device AI Processing & Privacy First Design
FinnAI is designed as an on-device AI assistant. AI-generated responses are processed locally on your Android device using mmap-backed GGUF inference engines. When automatic web search is used, the latest request is also used as described below.

- **No Remote AI Servers**: Your conversations are not sent to FinnAI or third-party AI cloud inference providers. The one exception is the optional FinnAI Code mode (section 2.C): it sends data to a provider only after you add that provider's API key and choose one of its models. FinnAI Code uses the on-device model until you do.
- **Encrypted Local Storage**: Your saved conversation history is stored strictly on your local device with authenticated AES-256-GCM encryption. Encryption keys are managed using OS-enforced secure key storage (`FlutterSecureStorage`).
- **Other Local Features**: Creations, Flows, profile preferences, custom instructions, pinned chats, and your access choices are stored in the app's private local storage. They are used only to provide the features you select and are not sent to an AI cloud service.
- **FinnAI Code**: Coding sessions and the project folders they work in are stored in the app's private local storage as ordinary files; they are not part of the encrypted conversation history above. API keys you add are kept in the operating system's secure key storage, and only the last four characters are stored in the app's own files.
- **You (what FinnAI remembers)**: Things you add to You, things you save from a reply with "Remember in You", and statements FinnAI notices in your own messages (for example "I am a designer") are kept in a local file on your device. Noticed statements wait in a review list until you keep them. Items you keep may be added to the on-device model's prompt, and the chats they were used in are named in the "From You" panel. You can edit, mute, forget or erase any of it, and turn learning or use off, in You > Privacy. None of it is sent anywhere.
- **Device access choices**: The choices you make about which kinds of device context (calendar, contacts, notifications, photos, files, location) FinnAI may use are stored locally. FinnAI does not read your calendar, contacts or location.
- **Exports and sharing**: "Export everything", "Export as text", "Share" and presentation export write a file to the app's temporary storage and hand it to the Android share sheet. FinnAI does not send these files anywhere; where they go is your choice in the app you share to.
- **Read aloud and spoken replies**: Replies are read aloud by on-device voices that FinnAI downloads once with the AI model (about 21 MB per language) and runs entirely on your device. Only if no on-device voice fits the language does FinnAI fall back to your device's own text-to-speech service. Nothing you say or hear is sent to FinnAI's servers.
- **Voice Input**: Voice input uses your device microphone (the app requests the Android `RECORD_AUDIO` permission). Your speech is turned into text on your device by a speech-recognition model (Whisper) that FinnAI downloads once, together with the on-device AI model during setup or when you update the app (or later, the first time you use voice mode, if that download was skipped), and removes with "Delete all data". The audio is processed in memory only while voice mode is listening; it is never sent to any server, including your platform's speech-recognition service, and FinnAI does not record or store it. The transcript is then processed by the on-device model like any typed message.

## Automatic Web Search

FinnAI automatically decides locally whether a request needs current internet
information — including news, recipes, explicit web lookups, and other
time-sensitive questions — and runs the web search on its own for those
search-intent prompts; no separate confirmation step is required. When it
searches, only the latest user request is sent over HTTPS to the search
providers DuckDuckGo (`api.duckduckgo.com` and `html.duckduckgo.com`) and
Wikipedia (`en.wikipedia.org`). Conversation history, saved profile data,
custom instructions, what FinnAI remembers in You, and Skills are not included. Search requests expose the
query and ordinary network metadata such as the device IP address to those
search providers. Retrieved excerpts are processed by the on-device model, and
FinnAI shows the source links used. When you open one of those source links to
read the page, FinnAI fetches that page from the third-party site that hosts it
over HTTPS; that request exposes the page URL and ordinary network metadata such
as the device IP address to that host. Only the search query and these page
requests are sent for search; conversation history, saved profile data, custom
instructions, and Skills are not included. If search is unavailable, FinnAI
falls back to a local answer. You can switch web lookups off in Settings > FinnAI Foundation > Look things up online.

For questions about current news, FinnAI asks Google News's public RSS feed
(`news.google.com`) for recent headlines, sending the topic words and your
device language and region. For a weather line in a Flow such as a morning
brief, FinnAI asks Open-Meteo (`geocoding-api.open-meteo.com` and
`api.open-meteo.com`) for the forecast of the city you entered, sending that
city name and the coordinates it resolves to. These requests also expose
ordinary network metadata such as the device IP address to those hosts. No
account or key is used, and nothing else from the device is sent.

### Scheduled Flows

A Flow you schedule runs only because you turned it on. FinnAI asks for
notification permission the first time you enable a scheduled Flow, and uses
the operating system's alarm service to remind you when it is due. Tapping the
notification opens FinnAI, which then runs the Flow (including any search
described above) and saves the result as a conversation in your encrypted
history. The Flow run log records which steps ran and whether they succeeded,
never the text of the result.

## 2. Network Usage & Third-Party Services
FinnAI uses network access exclusively for the following specific purposes:

### A. Model Downloads
When you download or update an AI model, the application connects to Hugging
Face (`huggingface.co`) over HTTPS to fetch the licensed LFM2.5-VL 1.6B `.gguf`
model files. The request necessarily exposes ordinary network metadata, such as
an IP address, to that host, but it does not include prompts or conversation
content. FinnAI itself is proprietary software, not an open-source application.

### C. FinnAI Code Providers (optional, off by default)
FinnAI Code can use a cloud model instead of the on-device model. This is off
until you add an API key for OpenRouter, Command Code, OpenCode Zen or OpenCode
Go, or the address of a server you run (a "custom" provider), and then choose one
of that provider's models. FinnAI does not operate these services and cannot see
your account with them.
- **What is sent**: When you use a provider's model, your messages, the contents of
  files the agent reads, and the output of commands it runs are sent to that
  provider over HTTPS (or, for a server on your own network that you add by
  address, over the connection you configured), together with your API key as an
  authorization header. The first use of each provider shows a notice saying so.
  The provider's own privacy policy and terms apply to what it receives.
- **Live lists and allowance**: Opening a provider's page asks that provider for
  its list of models and, for OpenRouter, for what is left to spend on your key.
  These requests carry your key and expose ordinary network metadata, such as an
  IP address, to that host. "Test key" sends a one-token request.
- **Your key**: The key is stored only in the operating system's secure storage,
  is never written to logs, and is removed by "Remove key" or "Delete FinnAI Code
  data".
- **Nothing else**: Commands the agent runs stay in a private project folder on
  your device and cannot reach the network unless you turn that on in Code
  settings.

### B. Optional In-App AI Response Reporting
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
- **Erase everything**: In Settings > Privacy and data, **Erase everything** attempts to purge conversation history, encryption keys, downloaded AI model files, creations, Flows, what FinnAI remembers in You, profile preferences, access choices, pinned chats, voice settings, FinnAI Code sessions, project folders, API keys and settings, and onboarding state. Any unpurged items are explicitly reported.
- **FinnAI Code**: Settings > Privacy and data in FinnAI Code has **Delete FinnAI Code data**, which removes every session, project folder, saved API key and Code setting. **Erase everything** in FinnAI includes it.
- **Delete all chats**, **Remove the model** and the **Erase everything in You** action each remove just their own data.
- **Free up memory**: FinnAI unloads the AI model from device RAM when memory is needed.
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
