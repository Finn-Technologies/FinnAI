# Upload Key Reset — Rebuild the Play AAB

This document is the handoff for what to do **after** Google Play Console
accepts an **upload key reset** for `com.abhiflex.finnai`. Follow it from top
to bottom. It is written so that either the app owner **or another agent**
can produce a new, publishable AAB that matches the newly registered upload
key.

> **Status (as of Aug 18, 2026):** the new upload key certificate has already
> been exported and **submitted to Google Play for the reset** (see
> [Where the keystore is](#where-the-keystore-is) below). We are now waiting
> for Play to confirm the new key is registered before building/uploading the
> first post-reset AAB. Steps 2–3 of this doc are **done**; start at
> Step 4 once Play confirms.

---

## 1. Background — what actually changes

Android app signing has two keys:

- **App signing key** — owned by Google Play. It signs the APKs that users
  actually install. **It does not change during an upload key reset.**
- **Upload key** — owned by you. It signs the AAB you upload. **This is the
  key that gets reset** when it is lost, compromised, or you simply want to
  rotate it.

Consequences of a reset:

- The **old** upload key becomes invalid for future uploads immediately.
- Existing installs and future updates are **unaffected** (the app signing
  key is unchanged).
- Your **first upload after the reset must be signed with the new upload key**
  and its certificate must match the one Play Console registered, or the
  upload is rejected with a "signed with the wrong key" error.

Do **not** try to "reuse" the old keystore after a reset — generate a brand
new keystore with a new key pair.

---

## 2. Step 0 — Request and confirm the reset (done in Play Console)

> **Status: DONE** — the certificate below was exported and submitted to
> Google Play for the reset. Awaiting Play's confirmation email before
> proceeding.

1. Open the Play Console: **Support → Contact us** (or the in-console
   "Upload key reset" help flow).
2. Identify the app: **com.abhiflex.finnai**.
3. Explain the reason (lost keystore / lost passwords / security rotation)
   and confirm you are the account owner.
4. Play will respond by email, then register the **new** upload key
   certificate that you send them — which means steps 3–4 below must happen
   **before** you can send the certificate. The usual order is:
   - Generate the new keystore (Step 2).
   - Export its public certificate (Step 3).
   - Attach that certificate to the Play support request / reset form.
   - Wait for Play to confirm the new key is registered.
   - Build and upload the new AAB (Steps 4–5).

> The reset cannot be completed until Play has your new certificate, so do
> Steps 2–3 first.

---

## 2b. Where the keystore is

**This is the signing setup already configured in the repo** (read from
`android/key.properties`, which is gitignored):

- **Keystore file:** `android/release-keystore.jks`
  (absolute path per `key.properties`:
  `/Users/abhi/Desktop/FinnAI/android/release-keystore.jks`)
- **Key alias:** `finn`
- **Export location:** `android/key.properties` (store + key password)
- **Exported public certificate:** `build/upload-key-cert.pem`
  (produced by `./tool/export_upload_key_cert.sh`)
- **Certificate fingerprint (what was sent to Play):**
  `DF:D5:96:69:F2:62:57:72:68:8D:BC:C4:3B:32:07:19:A5:02:7B:A3`

This keystore is what the release build signs with (via
`android/app/build.gradle.kts`), so once Play confirms the reset, the
existing config needs **no changes** — just build and upload.

---

## 3. Step 1 — Generate a brand-new upload keystore

Never commit keystores or passwords. Everything below is already covered by
`.gitignore` (`**/key.properties`, `*.jks`, `*.keystore`, `*.p12`, `*.pem`,
`.env*`).

Pick a strong password and keep the keystore + passwords in an encrypted
vault / offline backup — losing the **new** key means another reset.

```bash
# From the repo root. Create the keystore OUTSIDE the repo is fine too
# (e.g. ~/secrets/finnai-upload-YYYY.jks), but the build config below
# expects android/app/<file> or an absolute path.
keytool -genkeypair -v \
  -keystore upload-key.jks \
  -alias upload \
  -keyalg RSA \
  -keysize 4096 \
  -validity 10000 \
  -storepass 'REPLACE_WITH_STRONG_PASSWORD' \
  -keypass 'REPLACE_WITH_STRONG_PASSWORD' \
  -dname "CN=Finn AI, OU=Mobile, O=FinnAI, L=Unknown, ST=Unknown, C=US"
```

Notes:

- `keytool` comes from the JDK. On macOS use Android Studio's JBR
  (`/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool`)
  or set `JAVA_HOME`.
- Using the same password for store and key is fine; they can differ.
- **Back up** `upload-key.jks` and its passwords before continuing.

---

## 4. Step 2 — Configure the build to sign with the new key

The Gradle build (`android/app/build.gradle.kts`) reads signing config from
**one of**:

**Option A — `android/key.properties`** (recommended for local builds):

```properties
storeFile=upload-key.jks
storePassword=REPLACE_WITH_STRONG_PASSWORD
keyAlias=upload
keyPassword=REPLACE_WITH_STRONG_PASSWORD
```

`storeFile` is resolved relative to `android/app/`, so `upload-key.jks`
must sit at `android/app/upload-key.jks` (or use an absolute path).

**Option B — environment variables** (recommended for CI):

```bash
export KEYSTORE_PATH=/absolute/path/to/upload-key.jks
export KEYSTORE_PASSWORD='...'
export KEY_ALIAS=upload
export KEY_PASSWORD='...'
```

The build fails loudly (it never silently falls back to debug signing) if
signing is missing, so an empty config is immediately visible.

---

## 5. Step 3 — Export the public certificate and verify the fingerprint

The reset flow needs the **public** certificate (PEM) — never send the
keystore or passwords to Play.

```bash
./tool/export_upload_key_cert.sh build/upload-key-cert.pem
```

This prints the certificate's **SHA1** (and SHA-256) fingerprint. Verify:

- The **SHA1 matches the "Upload key certificate"** shown in
  Play Console → **Setup → App signing**.
- If Play shows a SHA-256 instead, the script prints that too.

Only proceed once the fingerprint matches what Play registered. If it does
not match, either the wrong keystore was configured or the reset was not
completed — do not upload.

---

## 6. Step 4 — Build the publishable AAB

From the repo root:

```bash
./tool/build_play_release.sh
```

This verifies production endpoints, runs the release verification suite,
then produces:

```
build/app/outputs/bundle/release/app-release.aab
```

Before uploading, confirm the AAB really is signed with the new key:

```bash
# jar-signature check for AABs (they are ZIP/JAR based)
unzip -p build/app/outputs/bundle/release/app-release.aab \
  META-INF/upload.RSA 2>/dev/null >/dev/null \
  && keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab \
  | grep -iE "Owner:|SHA1:" | head -4
```

The SHA1 must equal the fingerprint from Step 3. (If `keytool -printcert
-jarfile` is unavailable for AABs, build a quick APK with
`flutter build apk --release --target-platform android-arm64` and check it
with `apksigner verify --print-certs app-release.apk` — the signing config
is identical.)

### Version code

Every upload must have a **higher `versionCode`** than anything previously
uploaded. `versionCode` comes from `pubspec.yaml` (`version: 1.0.2+3` →
code `3`). If the previous upload was already version code 3, bump to `4`
(e.g. `version: 1.0.3+4`) before building. Do not reuse an already-uploaded
version code.

---

## 7. Step 5 — Upload and verify in Play Console

1. Upload `app-release.aab` to the app's **Production (or appropriate)
   release track** in Play Console.
2. If the reset was completed correctly, Play accepts the upload and the
   release shows "signed with the new upload key".
3. If Play rejects with a signing mismatch, stop: re-check that the
   fingerprint in Step 3 matches Play's registered upload key, that
   `key.properties`/env vars point at the **new** keystore, and that the
   reset was actually completed.
4. After the first successful upload, **archive or delete the old keystore**
   so nobody accidentally signs a future upload with a key Play no longer
   accepts.

---

## 8. Checklist for the agent doing this

- [x] Reset requested by Play Console support — **certificate submitted**
      (`build/upload-key-cert.pem`, SHA1 `DF:D5:96:…:7B:A3`); awaiting Play's
      confirmation.
- [x] New keystore generated (`keytool -genkeypair`) and **backed up** —
      `android/release-keystore.jks`, alias `finn`.
- [x] `android/key.properties` (or `KEYSTORE_*` env vars) point at the new
      keystore.
- [ ] `./tool/export_upload_key_cert.sh` output SHA1 matches the upload key
      certificate in Play Console **once Play confirms the reset**.
- [ ] `pubspec.yaml` versionCode bumped above the last upload.
- [ ] `./tool/build_play_release.sh` succeeds and produces the AAB.
- [ ] AAB signature fingerprint matches Step 3's fingerprint.
- [ ] AAB uploaded; Play accepts it.
- [ ] Old keystore retired.

Related: `docs/PLAY_CONSOLE_CHECKLIST.md` (full release flow) and
`tool/export_upload_key_cert.sh` (certificate export used above).
