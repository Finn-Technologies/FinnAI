# Security and Privacy Architecture

## Overview
FinnAI is designed as an on-device, privacy-first AI assistant. All inference runs locally on the user's Android device using quantized GGUF models.

---

## 1. Data Classification

| Data Type | Storage Location | Encryption Standard | Network Exposure |
|---|---|---|---|
| Chat History & Messages | Local App Private Storage (`conversations.v2.enc`) | AES-256-GCM via `package:cryptography` | Latest request only when automatic web search is needed; history is never sent |
| Creations | Local App Private Storage (`creations.json`) | Android application sandbox | None |
| Profile Preferences & Custom Instructions | Local App Private Storage (`user_personalization.json`) | Android application sandbox | None |
| Skills | Local App Private Storage (`skills.json`) | Android application sandbox | None |
| Encryption Master Key | `FlutterSecureStorage` (Android KeyStore / KeyChain) | 256-bit random key in OS-enforced Hardware KeyStore | None |
| AI Model Weights | Local Cache Directory (`.gguf` files) | SHA-256 integrity verified | Download only from Hugging Face |
| AI Response Reports | Transient in memory until handed to the user's mail app | User-controlled email (only after review and Send) | `finn_org@proton.me`; retention is governed by the receiving mailbox |
| Web Search Query | Transient in memory | HTTPS/TLS | Search provider, only for requests locally classified as needing web information |

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
- **Delete All Local Data**: Attempts purging encrypted conversations, master encryption keys, downloaded `.gguf` model files, partial downloads, creations, profile preferences, Skills, and onboarding state, returning a structured `DeletionResult`.
