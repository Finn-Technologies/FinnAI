# Native 16 KB Page-Size Verification

## Status

**ELF and APK packaging verification: passed.**

**Runtime validation on a device or emulator using a 16 KB kernel: still
required before production.**

FinnAI packages its native inference runtime in
`android/app/libs/llama-cpp-dart.aar`. Every arm64 shared library in that AAR
is now built from source with Android NDK `28.2.13676358` and has 16 KB
(`0x4000`) `PT_LOAD` alignment.

Android supports 16 KB devices beginning with Android 15. Google Play requires
new apps and updates targeting Android 15 or later to support 16 KB page sizes.
The Android documentation recommends AGP 8.5.1 or newer, NDK r28 or newer,
16 KB-compatible prebuilt dependencies, ELF inspection, APK `zipalign`
verification, and a real 16 KB runtime test.

Reference:
<https://developer.android.com/guide/practices/page-sizes>

## Provenance

The replaced 4 KB AAR was not patched or relinked. It was discarded and all
five libraries were compiled again from their original C/C++ sources.

| Item | Pinned value |
|---|---|
| Dart dependency | `llama_cpp_dart 0.9.0-dev.9` |
| Upstream tag | `v0.9.0-dev.9` |
| `llama_cpp_dart` commit | `1a8c7563cb5382e23bcd20dc5720fc8d8099ec58` |
| `llama.cpp` submodule commit | `d6d0ce8215a1c324e8de04b52f9dd65c5edc129f` |
| Android NDK | `28.2.13676358` |
| Android ABI | `arm64-v8a` |
| Android API floor | 26 |

Before replacement, the repository AAR had SHA-256
`73ab5e755c57ae4c3e06fc728c9e649152e89db99e2b2deba99f3a5fcff41028`.
That hash matched the official upstream `v0.9.0-dev.9` release AAR exactly,
establishing that the pinned tag is the correct source for FinnAI's binary.

The source build uses the upstream `tool/build_android_aar.sh` with NDK r28.
NDK r28 and newer produce 16 KB-aligned ELF files by default.

The tracked rebuilt AAR has SHA-256
`db33d633e364101e77a87aafd77f172627cce7db832988bb0adaefd072418745`.
ZIP timestamps make the container hash build-time dependent, but a second
clean build produced byte-identical `.so` payloads for all five libraries.

Rebuild command:

```bash
tool/rebuild_llama_android_aar.sh \
  --ndk "$HOME/Library/Android/sdk/ndk/28.2.13676358"
```

The wrapper validates both pinned commits before building and rejects the
result unless every packaged shared library passes the alignment check.

## Verified AAR result

Run:

```bash
python3 tool/verify_native_alignment.py \
  android/app/libs/llama-cpp-dart.aar
```

Verified output:

```text
OK: libggml-base.so: PT_LOAD alignments [0x4000, 0x4000, 0x4000], minimum 0x4000
OK: libggml-cpu-android_armv8.0_1.so: PT_LOAD alignments [0x4000, 0x4000, 0x4000], minimum 0x4000
OK: libggml-cpu-android_armv8.2_1.so: PT_LOAD alignments [0x4000, 0x4000, 0x4000], minimum 0x4000
OK: libggml-cpu-android_armv8.2_2.so: PT_LOAD alignments [0x4000, 0x4000, 0x4000], minimum 0x4000
OK: libggml-cpu-android_armv8.6_1.so: PT_LOAD alignments [0x4000, 0x4000, 0x4000], minimum 0x4000
OK: libggml-cpu-android_armv9.0_1.so: PT_LOAD alignments [0x4000, 0x4000, 0x4000], minimum 0x4000
OK: libggml-cpu-android_armv9.2_1.so: PT_LOAD alignments [0x4000, 0x4000, 0x4000], minimum 0x4000
OK: libggml-cpu-android_armv9.2_2.so: PT_LOAD alignments [0x4000, 0x4000, 0x4000], minimum 0x4000
OK: libggml-vulkan.so: PT_LOAD alignments [0x4000, 0x4000, 0x4000], minimum 0x4000
OK: libggml.so: PT_LOAD alignments [0x4000, 0x4000, 0x4000], minimum 0x4000
OK: libllama.so: PT_LOAD alignments [0x4000, 0x4000, 0x4000], minimum 0x4000
OK: libmtmd.so: PT_LOAD alignments [0x4000, 0x4000, 0x4000], minimum 0x4000
```

`libggml-vulkan.so` is checked here because it is part of the AAR, but the
Android app does not package it: `accelerateIfAvailable` returns `null` on
Android and the planner pins `gpuLayers` to 0, so the Vulkan backend is
unreachable there. `android/app/build.gradle.kts` excludes it from the APK,
which removes roughly 71 MB of dead native payload. The release gate therefore
checks the ten CPU/runtime libraries the app actually ships.

The source-built libraries retain the same complete public C ABI as the
original release libraries:

| Library | Original C symbols | Rebuilt C symbols | Missing |
|---|---:|---:|---:|
| `libggml-base.so` | 671 | 671 | 0 |
| `libggml-cpu.so` | 327 | 327 | 0 |
| `libggml.so` | 16 | 16 | 0 |
| `libllama.so` | 237 | 237 | 0 |
| `libmtmd.so` | 108 | 108 | 0 |

## Release artifact checks

`tool/verify_release.sh` performs both required static checks against the
actual release APK:

1. `zipalign -c -P 16 -v 4` validates ZIP entry alignment.
2. Its ELF parser validates every packaged `.so`, not only llama.cpp.

Both checks must remain passing for every release.

## Remaining runtime test

Static alignment proves that the binary is packaged correctly, but it does not
prove runtime behavior under a 16 KB kernel. Before production:

1. Boot an Android 15-or-newer arm64 emulator/device configured for 16 KB.
2. Confirm `adb shell getconf PAGE_SIZE` returns `16384`.
3. Install the release APK.
4. Load each eligible FinnAI model and complete multi-turn inference.
5. Exercise download resume, background/resume, context growth, and model
   unloading while monitoring for linker, mmap, and memory faults.

The connected OnePlus Nord uses a 4 KB kernel, so it can verify functional
compatibility of the rebuilt runtime but cannot close the 16 KB runtime-test
item.
