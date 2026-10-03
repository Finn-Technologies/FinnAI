#!/usr/bin/env bash
#
# Rebuilds third_party/sherpa_onnx_android_arm64's native libraries from the
# sherpa-onnx source with text-to-speech compiled out.
#
# Why: the prebuilt libsherpa-onnx-c-api.so that the `sherpa_onnx` Dart package
# ships links espeak-ng, a GPL-3.0 phonemizer, for its TTS. FinnAI only uses the
# speech *recognition* half (Whisper + Silero VAD), so the build below drops
# TTS and with it espeak-ng. Verify with:
#
#   strings -a libsherpa-onnx-c-api.so | grep -ci 'espeak[_-]ng'   # expect 0
#
# (a plain `grep -i espeak` also matches "OfflineSpeaker", which is harmless.)
#
# Needs: git, curl, unzip, an Android NDK (ANDROID_NDK) and CMake. The upstream
# script calls `wget`; a tiny shim over curl is created if it is missing.
#
#   ANDROID_NDK=$HOME/Library/Android/sdk/ndk/28.2.13676358 ./tool/rebuild_sherpa_android.sh
set -euo pipefail

VERSION="${SHERPA_ONNX_VERSION:-v1.13.8}"
WORK="${WORK_DIR:-$(mktemp -d)}"
OUT="$(cd "$(dirname "$0")/.." && pwd)/third_party/sherpa_onnx_android_arm64/android/src/main/jniLibs/arm64-v8a"

: "${ANDROID_NDK:?set ANDROID_NDK to an NDK directory}"

if ! command -v wget >/dev/null; then
  mkdir -p "$WORK/bin"
  printf '#!/bin/bash\nexec curl -L -s -O "${@: -1}"\n' > "$WORK/bin/wget"
  chmod +x "$WORK/bin/wget"
  export PATH="$WORK/bin:$PATH"
fi
if ! command -v cmake >/dev/null && [ -d "$HOME/Library/Android/sdk/cmake" ]; then
  export PATH="$(ls -d "$HOME"/Library/Android/sdk/cmake/*/bin | head -1):$PATH"
fi

git clone --depth 1 --branch "$VERSION" https://github.com/k2-fsa/sherpa-onnx.git "$WORK/sherpa-onnx"
cd "$WORK/sherpa-onnx"

SHERPA_ONNX_ENABLE_TTS=OFF \
SHERPA_ONNX_ENABLE_C_API=ON \
SHERPA_ONNX_ENABLE_JNI=OFF \
SHERPA_ONNX_ANDROID_PLATFORM=android-26 \
  bash build-android-arm64-v8a.sh

cp -v build-android-arm64-v8a/install/lib/libsherpa-onnx-c-api.so \
      build-android-arm64-v8a/install/lib/libsherpa-onnx-cxx-api.so \
      build-android-arm64-v8a/install/lib/libonnxruntime.so "$OUT/"

if strings -a "$OUT/libsherpa-onnx-c-api.so" | grep -qi 'espeak[_-]ng'; then
  echo "ERROR: espeak-ng is still in the library" >&2
  exit 1
fi
echo "ok: espeak-ng is not in libsherpa-onnx-c-api.so"
