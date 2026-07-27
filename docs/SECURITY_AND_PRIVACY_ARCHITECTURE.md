# Security and Privacy Architecture

## Overview
FinnAI is designed as an on-device, privacy-first AI assistant. All inference runs locally on the user's Android device using quantized GGUF models.

---

## 1. Data Classification

| Data Type | Storage Location | Encryption Standard | Network Exposure |
|---|---|---|---|
| Chat History & Messages | Local App Private Storage (`conversations.v2.enc`) | AES-256-GCM via `package:cryptography` | None (Stored locally) |
| Encryption Master Key | `FlutterSecureStorage` (Android KeyStore / KeyChain) | 256-bit random key in OS-enforced Hardware KeyStore | None |
| AI Model Weights | Local Cache Directory (`.gguf` files) | SHA-256 integrity verified | Download only from Hugging Face |
| AdMob Data & Consent | Local Preferences & Google UMP SDK | Google Standard Advertising Privacy | Google AdMob Servers |
| AI Response Reports | Transient in memory | HTTPS TLS 1.3 (When user submits & endpoint configured) | Configured Reporting Endpoint (`FINN_REPORT_ENDPOINT`) |

---

## 2. Conversation Encryption Architecture

### Scheme
FinnAI uses **AES-256-GCM** authenticated encryption provided by the maintained `cryptography` package:

```text
Plaintext JSON -> AES-256-GCM (SecretKey, 12-byte Nonce) -> (Ciphertext + 16-byte MAC Tag)
Saved Envelope: { "version": "2", "algorithm": "AES-256-GCM", "nonce": "...", "ciphertext": "...", "mac": "..." }
```

### Key Generation & Recovery Safeguards
- Master Key: 32 cryptographically secure random bytes (256-bit `SecretKey`).
- Key Alias: `finn_ai_conversation_master_key_v2` stored in `FlutterSecureStorage` (backed by Android KeyStore hardware security module).
- **Key Loss & Recovery Rule**: If `conversations.v2.enc` exists on disk but its encryption key is missing or invalid, `ConversationStore` enters a read-only storage error state. It **never** generates a replacement key, **never** overwrites the existing encrypted file, and **disables scheduled saves** to protect existing history.

### Atomic Migration & Write Safeguards
1. Encrypted contents written to a temporary file (`conversations.v2.enc.tmp`).
2. Temporary file read and decrypted in `.tmp` state to verify contents match source.
3. Atomic file rename to `conversations.v2.enc`.
4. Final file read and decrypted to confirm integrity before deleting legacy plaintext `conversations.json`.
5. On failure, temporary file is removed and legacy plaintext is preserved.

---

## 3. User Controls & Data Purging
- **Clear Chat History**: Purges saved conversations.
- **Purge AI Memory**: Unloads AI models from RAM without deleting `.gguf` files.
- **Delete All Local Data**: Attempts purging all encrypted conversations, master encryption keys, downloaded `.gguf` model files, partial downloads, and app caches, returning a structured `DeletionResult`.

---

## 4. AdMob & Consent Management
- Built with Google User Messaging Platform (UMP) SDK (`AdConsentService`).
- Ad requests are blocked until consent status (`canRequestAds`) returns true.
- Debug builds strictly utilize official Google AdMob test Unit IDs.
- Production builds use production IDs.
- Banner ads collapse cleanly to `SizedBox.shrink()` (0 height) when no ad is loaded or when consent is missing.
