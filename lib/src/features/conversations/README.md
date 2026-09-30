# conversations — encrypted history

**Purpose.** Persist conversations: AES-256-GCM files, key in Android KeyStore.

**Entry point.** `conversation_store.dart`.

**Invariants.**
- If the key is missing but an encrypted file exists the store refuses to overwrite (`_storageError`). That is deliberate; never "fix" it by deleting the file.
- One corrupt message must not hide the rest of the history.
- Deleting all data removes the file *and* the key.
