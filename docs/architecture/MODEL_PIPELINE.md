# Model pipeline

FinnAI ships **one** model. Everything below keys off that single artifact identity, so a change to
the catalog ripples through download, verification, storage, settings, and deletion.

```text
catalog (compile-time constant)
   │  finnModels.single  +  finnMmproj
   ▼
detect install state ──► download ──► verify ──► promote ──► load ──► infer ──► (delete)
  isInstalled()      .part files   size+GGUF+sha   rename    llama   tokens
```

## 1. Catalog

`lib/src/engine/catalog/model_catalog.dart` holds two `const` records:

- `finnModels` — a one-element list (`finnModels.single`). `FinnModelTier` has a single value,
  `standard`.
- `finnMmproj` — the SigLIP2 vision projector, downloaded **after** the language model.

Each record pins `downloadUrl` (with an immutable 40-char revision), `expectedBytes`, and
`sha256Digest`. `test/app/release_hardening_test.dart` asserts the URL shape and digest format, and
that no mutable `/resolve/main/` URL sneaks in.

> **Verify digests against Hugging Face before changing them.** The LFS API returns them:
> `curl -s "https://huggingface.co/api/models/<repo>/tree/<revision>"` — `lfs.oid` **is** the
> SHA-256 and `size` is `expectedBytes`.

## 2. Install state

`FinnAccelerator.isInstalled(model)` is the cheap gate used by bootstrap, onboarding and settings:

1. `_verifiedModels` in-memory cache, else
2. `_isVerifiedModelFile` — file exists, **exact** `expectedBytes`, and the first 4 bytes are the
   GGUF magic (`_looksLikeGguf`).

This is deliberately not a full hash (it runs on every launch). The SHA-256 gate happens once, at
download time — see the invariant below.

## 3. Download

Entry point: `FinnAccelerator.install(model)` → `_runInstall` → `_ensureDownloaded` → then
`_preinstallMmproj`.

Two implementations exist behind one interface:

- **Android** — `_ensureArtifactWithService` delegates to the `ModelDownloadService` foreground
  service over the `finn_ai/model_download` method channel. The service downloads 16 byte-ranges in
  parallel into one file, persists per-range progress every 4 s, and is supervised by Dart: if the
  heartbeat stalls for 20 s the service is cancelled and restarted (up to 6 times) so a dead thread
  resumes from the persisted offsets.
- **Everything else** — `_ensureArtifactDart` / `_downloadSegmented` / `_downloadSingleStream` do
  the same in pure Dart, with a 25 s idle watchdog and up to 5 attempts per range.

Both write to `<target>.part` and only rename into place after the byte count and SHA-256 match.
Progress is aggregated across the model **and** the projector so the install bar is one honest
number (`installProgress`).

### Invariants

- **A promoted artifact is either correct or deleted.** `_verifyPromotedArtifact` removes the file
  when the digest fails. Without that, a right-sized-but-corrupt model would pass
  `_isVerifiedModelFile` forever and could never be re-downloaded.
- **Resume is byte-exact.** Over-long partials are discarded, exact-length partials are promoted
  without re-downloading, and the aggregate counter is re-seeded on resume.
- **The projector is optional but must be resumed.** Text chat works without it, so failures are
  tolerated; `_resumeInterruptedMmproj` retries an orphaned `.part` at startup so vision does not
  silently stay disabled after a process kill.

## 4. Loading

`_ensureLoaded` → `_loadModel`:

1. `AdaptiveInferenceEngine.select` may restore a persisted backend choice (desktop/Linux only —
   Android is pinned to CPU) or fall back to the heuristic plan from
   `DeviceProfiler.plan`.
2. `LlamaEngine.spawn` loads the GGUF with `mmap` (`useMmap: true`, `useMlock: false`) and attaches
   the projector when `hasMmproj`.
3. If the spawn fails or times out, the engine falls back CPU-only, then to an F16 KV cache as the
   compatibility baseline.
4. A `_runtimeEpoch` check disposes the freshly spawned engine if a memory release happened while
   loading.

## 5. Inference

Generation is queued (`generateReplyQueued`) so only one turn runs at a time. Per conversation the
engine keeps a session with a prepared prefix state, so a warm follow-up only needs to prefill the
new turns. `releaseMemory()` drops the runtime when the app is backgrounded.

## 6. Deletion

`remove` / `removeAllModels` / `removeMmproj` delete the artifact, the `.part`, per-range scratch
files (`<partial>.r0…r15`) and the prefix-state directory. `removeAllModels` first cancels any
in-flight install — otherwise the foreground service can rename a partial back into place *after*
the files were unlinked, resurrecting data the user asked to erase.

## Log tags

| Tag | Meaning |
|---|---|
| `FINN_INSTALLING_MODEL` | Download starting, with the resolved URL |
| `FINN_INSTALL_ARTIFACT_COMPLETE` | One artifact finished; payload is its byte count |
| `FINN_RESUME` | Startup resume of an interrupted transfer |
| `FINN_ENGINE` | Live engine config (threads, batch, KV type, context, device) |
| `FINN_PREFIX` | Prefix-cache hit/miss and preparation timing |
| `FINN_PROMPT` | Prompt token breakdown by section |
| `FINN_TTFT` / `FINN_TTFT_SUMMARY` | Time-to-first-token trace |
| `FINN_PERF` | End-of-turn totals (tokens, decode ms, tok/s) |
| `FINN_MMPROJ` | Projector-specific failures |

## Inspection on a device

```bash
adb shell run-as com.abhiflex.finnai ls -la files/models/
adb logcat -s flutter | grep FINN_
```
