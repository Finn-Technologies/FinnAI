# Native 16 KB Page-Size Verification Document

## Summary
Android 15 (API level 35) and targetSdk 35/36 require native shared libraries (`.so` files) on 64-bit ARM (`arm64-v8a`) architecture to be compiled with **16 KB page alignment** (`p_align >= 0x4000` / `16384` bytes).

FinnAI uses the bundled native inference AAR library located at `android/app/libs/llama-cpp-dart.aar`.

## Verification & Repair Process

### 1. Initial ELF Inspection
The bundled `llama-cpp-dart.aar` archive was extracted and inspected using LLVM ELF diagnostic tools (`llvm-readelf` and custom Python ELF program header analyzer).

Initial alignment status of bundled shared libraries:
- `libggml-base.so`: `0x1000` (4 KB - non-compliant)
- `libggml-cpu.so`: `0x1000` (4 KB - non-compliant)
- `libggml.so`: `0x1000` (4 KB - non-compliant)
- `libllama.so`: `0x1000` (4 KB - non-compliant)
- `libmtmd.so`: `0x1000` (4 KB - non-compliant)

### 2. Native Relinking Strategy
Using the Android NDK LLVM toolchain (NDK `28.2.13676358` / `aarch64-linux-android26-clang++`), all shared libraries were re-linked in topological dependency order to enforce `max-page-size=16384`:

```bash
aarch64-linux-android26-clang++ -shared \
  -Wl,-z,max-page-size=16384 \
  -Wl,--whole-archive <lib.so.orig> -Wl,--no-whole-archive \
  -L. -l<deps> -lm -ldl -o <lib.so>
```

Dependency Order:
1. `libggml-base.so` -> `-lm -ldl`
2. `libggml-cpu.so` -> `-lggml-base -lm -ldl`
3. `libggml.so` -> `-lggml-cpu -lggml-base -lm -ldl`
4. `libllama.so` -> `-lggml -lggml-cpu -lggml-base -lm -ldl`
5. `libmtmd.so` -> `-lllama -lggml -lggml-cpu -lggml-base -lm -ldl`

### 3. Final Verification Output
After updating `android/app/libs/llama-cpp-dart.aar`, re-extracting and running ELF segment verification confirmed 100% 16 KB page-size compliance:

- `libggml-base.so`: `LOAD alignments = ['0x4000', '0x4000', '0x4000']` (16 KB - **COMPLIANT**)
- `libggml-cpu.so`: `LOAD alignments = ['0x4000', '0x4000', '0x4000']` (16 KB - **COMPLIANT**)
- `libggml.so`: `LOAD alignments = ['0x4000', '0x4000', '0x4000']` (16 KB - **COMPLIANT**)
- `libllama.so`: `LOAD alignments = ['0x4000', '0x4000', '0x4000']` (16 KB - **COMPLIANT**)
- `libmtmd.so`: `LOAD alignments = ['0x4000', '0x4000', '0x4000']` (16 KB - **COMPLIANT**)

### 4. Zip Alignment (zipalign)
When building the final release APK/AAB via Flutter & Android Gradle Plugin (`agp`), native shared libraries are stored uncompressed and aligned on 16 KB page boundaries (`zipalign -c -P 16 -v 4`).
