# Security and Privacy Architecture

## Overview
FinnAI is designed as an on-device, privacy-first AI assistant. All inference runs locally on the user's Android device using quantized GGUF models.

---

## 1. Data Classification

| Data Type | Storage Location | Encryption Standard | Network Exposure |
|---|---|---|---|
| Chat History & Messages | Local App Private Storage (`conversations.json.enc`) | AES-256-CTR + HMAC-SHA256 Encrypt-Then-MAC | None (Stored locally) |
| Encryption Master Key | `FlutterSecureStorage` (Android KeyStore / KeyChain) | OS-enforced Hardware KeyStore | None |
| AI Model Weights | Local Cache Directory (`.gguf` files) | SHA-256 integrity verified | Download only from Hugging Face |
| Admob Data & Consent | Local Preferences & Google UMP SDK | Google Standard Advertising Privacy | Google AdMob Servers |
| AI Response Reports | Transient in memory | HTTPS TLS 1.3 (When user submits) | Configured Reporting Endpoint |

---

## 2. Conversation Encryption Architecture

### Scheme
FinnAI uses an **Encrypt-Then-MAC** scheme combining AES-256 in Counter Mode (CTR) for confidentiality and HMAC-SHA256 for integrity and authenticity:

```text
Plaintext JSON -> AES-256-CTR (Key_enc, IV) -> Ciphertext
(Version || Algorithm || IV || Ciphertext) -> HMAC-SHA256 (Key_mac) -> MAC Tag
```

### Key Generation & Storage
- Master Key: 64 cryptographically secure random bytes (`crypto.getRandomBytes`).
- Key_enc (32 bytes): First half of Master Key used for AES-256-CTR encryption.
- Key_mac (32 bytes): Second half of Master Key used for HMAC-SHA256 tag calculation.
- Alias: `finn_ai_conversation_master_key_v1` stored in `FlutterSecureStorage` (backed by Android KeyStore hardware security module).

### Atomic Write & Integrity Safeguards
1. Encrypted contents written to a temporary file (`conversations.json.enc.tmp`).
2. Atomic file rename to `conversations.json.enc`.
3. Legacy plaintext `conversations.json` migrated automatically on startup and securely deleted.
4. Tamper detection: If HMAC-SHA256 fails during decryption, an error is thrown and unauthenticated data is rejected.

---

## 3. User Controls & Data Purging
- **Clear Chat History**: Purges saved conversations.
- **Purge AI Memory**: Unloads AI models from RAM without deleting `.gguf` files.
- **Delete All Local Data**: Deletes all encrypted conversations, master encryption keys, downloaded `.gguf` model files, and app caches.

---

## 4. AdMob & Consent Management
- Built with Google User Messaging Platform (UMP) SDK (`AdConsentService`).
- Ad requests are blocked until consent status (`canRequestAds`) returns true.
- Debug builds strictly utilize official Google AdMob test Unit IDs (`ca-app-pub-3940256099942544/...`).
- Production builds use production IDs (`ca-app-pub-4976264332074869/...`).
- Banner ads collapse cleanly to `SizedBox.shrink()` on failure or when consent is denied.
