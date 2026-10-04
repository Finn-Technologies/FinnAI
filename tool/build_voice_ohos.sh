#!/usr/bin/env bash
set -euo pipefail

# Build FinnAI's OpenHarmony speech-recognition libraries: libonnxruntime.so and
# the sherpa-onnx C API, installed into ohos/entry/libs/arm64-v8a/ so the Dart
# FFI in package:sherpa_onnx can load them.
#
# This is the OHOS sibling of tool/rebuild_sherpa_android.sh. Like
# tool/rebuild_llama_ohos.sh it must be *rebuilt* when the SDK moves, never
# re-copied: the HarmonyOS NDK sysroot is what makes the libraries loadable.
#
# Why it is two projects
# ----------------------
# sherpa-onnx downloads a prebuilt onnxruntime per platform and there is no
# OHOS build to download, so onnxruntime is built here first and handed to
# sherpa-onnx via SHERPA_ONNXRUNTIME_INCLUDE_DIR / SHERPA_ONNXRUNTIME_LIB_DIR.
#
# Text-to-speech stays compiled OUT (SHERPA_ONNX_ENABLE_TTS=OFF). The prebuilt
# libsherpa-onnx-c-api.so links espeak-ng, a GPL-3.0 phonemizer; FinnAI only
# uses the recognition half (Whisper + Silero VAD). The script fails if espeak-ng
# ends up in the library, the same gate tool/rebuild_sherpa_android.sh applies.
#
# What this does NOT give you: on-device spoken replies. Those need libfinn_tts.so
# (android/app/src/main/cpp/finn_supertonic.cc) plus PCM playback, neither of
# which is built for OHOS, so OHOS reads replies with the system engine.
#
# Usage:
#   source tool/ohos_env.sh
#   bash tool/build_voice_ohos.sh [--jobs N] [--keep-build]
#
# Long: onnxruntime alone is ~900 sources. Pass --jobs to match the machine.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ORT_VERSION="${ORT_VERSION:-v1.28.2}"
SHERPA_VERSION="${SHERPA_ONNX_VERSION:-v1.13.8}"
ORT_REPOSITORY="https://github.com/microsoft/onnxruntime.git"
SHERPA_REPOSITORY="https://github.com/k2-fsa/sherpa-onnx.git"
PATCH_FILE="$ROOT/tool/onnxruntime_ohos_build.patch"
OUTPUT="$ROOT/ohos/entry/libs/arm64-v8a"
HEADERS="$ROOT/third_party/onnxruntime/include"
BUILD_ROOT="${BUILD_ROOT:-${TMPDIR:-/tmp}/finn-voice-ohos}"
JOBS="$(sysctl -n hw.ncpu 2>/dev/null || echo 4)"
KEEP_BUILD=false

usage() {
  echo "Usage: $0 [--jobs N] [--keep-build]"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --jobs) JOBS="$2"; shift 2 ;;
    --keep-build) KEEP_BUILD=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

NATIVE="${DEVECO_SDK_HOME:-$HOME/Developer/command-line-tools/sdk}/default/openharmony/native"
TOOLCHAIN="$NATIVE/build/cmake/ohos.toolchain.cmake"
STRIP="$NATIVE/llvm/bin/llvm-strip"
if [[ ! -f "$TOOLCHAIN" ]]; then
  echo "HarmonyOS NDK toolchain not found at $TOOLCHAIN" >&2
  echo "Source tool/ohos_env.sh or set DEVECO_SDK_HOME." >&2
  exit 2
fi
for tool in cmake ninja git python3; do
  command -v "$tool" >/dev/null || { echo "$tool not found." >&2; exit 2; }
done

# Same guard as tool/rebuild_llama_ohos.sh: a sysroot exporting
# __register_atfork is newer than the target OS, and libraries built against it
# fail to dlopen on HarmonyOS 6.x.
SYSLIB="$NATIVE/sysroot/usr/lib/aarch64-linux-ohos/libc.so"
if [[ -f "$SYSLIB" ]] && command -v nm >/dev/null; then
  if nm -D "$SYSLIB" 2>/dev/null | grep -q "__register_atfork"; then
    echo "Refusing to build: $SYSLIB exports __register_atfork." >&2
    exit 1
  fi
  echo "Sysroot OK: no __register_atfork (matches HarmonyOS 6.x libc)."
fi

mkdir -p "$BUILD_ROOT"
STAGE="$BUILD_ROOT/stage"
mkdir -p "$STAGE/lib"

# ---------------------------------------------------------------- onnxruntime
ORT_SRC="$BUILD_ROOT/onnxruntime"
if [[ ! -d "$ORT_SRC/.git" ]]; then
  echo "==> cloning onnxruntime $ORT_VERSION (large)"
  git clone --depth 1 --branch "$ORT_VERSION" --recursive --shallow-submodules \
    "$ORT_REPOSITORY" "$ORT_SRC"
fi

echo "==> applying OHOS patches to onnxruntime"
if git -C "$ORT_SRC" apply --reverse --check "$PATCH_FILE" 2>/dev/null; then
  echo "already applied"
else
  git -C "$ORT_SRC" apply --check "$PATCH_FILE"
  git -C "$ORT_SRC" apply "$PATCH_FILE"
fi

# The pytorch/cpuinfo dependency gates every platform source on a CMAKE_SYSTEM_NAME
# allowlist that has no OHOS, which leaves ARM64 init/deinit undefined at link
# time. HarmonyOS is Linux-compatible for its purposes (/proc/cpuinfo,
# sched_getaffinity), so teach it that.
CPUINFO="$ORT_SRC/cmake/external/pytorch_cpuinfo/CMakeLists.txt"
if [[ -f "$CPUINFO" ]] && ! grep -q "Emscripten|OHOS" "$CPUINFO"; then
  echo "==> teaching cpuinfo about OHOS"
  python3 - "$CPUINFO" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
s = p.read_text()
a_old = 'ELSEIF(NOT CMAKE_SYSTEM_NAME MATCHES "^(Windows|WindowsStore|CYGWIN|MSYS|Darwin|Linux|Android|FreeBSD|Emscripten)$")'
a_new = 'ELSEIF(NOT CMAKE_SYSTEM_NAME MATCHES "^(Windows|WindowsStore|CYGWIN|MSYS|Darwin|Linux|Android|FreeBSD|Emscripten|OHOS)$")'
s = s.replace(a_old, a_new, 1)
s = s.replace('CMAKE_SYSTEM_NAME STREQUAL "Linux"',
              'CMAKE_SYSTEM_NAME MATCHES "^(Linux|OHOS)$"')
p.write_text(s)
PY
fi

# ONNX Runtime ends its per-target warning list with "-Wshorten-64-to-32 -Werror"
# *after* CMAKE_CXX_FLAGS, so a suppression has to win by position:
# -Wno-<name> selects the warning, and a launcher that appends afterwards wins
# the promotion. ASM needs its own CMAKE_ASM_FLAGS -- CMake does not route ASM
# through the C/C++ flags, and MLAS's .S kernels are the first thing to fail.
LAUNCHER="$BUILD_ROOT/ohos-warn-launcher.sh"
cat > "$LAUNCHER" <<'LAUNCHER_EOF'
#!/bin/bash
exec "$@" -Wno-error -Wno-shorten-64-to-32
LAUNCHER_EOF
chmod +x "$LAUNCHER"

echo "==> building libonnxruntime.so with $JOBS jobs (long)"
cmake -G Ninja -B "$ORT_SRC/build_ohos" -S "$ORT_SRC/cmake" \
  -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
  -DOHOS_ARCH=arm64-v8a \
  -DOHOS_STL=c++_static \
  -DOHOS_PLATFORM_LEVEL=24 \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_FLAGS="-Wno-unused-command-line-argument" \
  -DCMAKE_CXX_FLAGS="-Wno-unused-command-line-argument" \
  -DCMAKE_ASM_FLAGS="-Wno-unused-command-line-argument" \
  -DCMAKE_C_COMPILER_LAUNCHER="$LAUNCHER" \
  -DCMAKE_CXX_COMPILER_LAUNCHER="$LAUNCHER" \
  -DCMAKE_ASM_COMPILER_LAUNCHER="$LAUNCHER" \
  -DPython3_EXECUTABLE="$(command -v python3)" \
  -DPython_EXECUTABLE="$(command -v python3)" \
  -Donnxruntime_BUILD_SHARED_LIB=ON \
  -Donnxruntime_BUILD_UNIT_TESTS=OFF \
  -Donnxruntime_ENABLE_LTO=OFF \
  -Donnxruntime_BUILD_PYTHON=OFF \
  -Donnxruntime_BUILD_JAVA=OFF \
  -Donnxruntime_USE_OPENMP=OFF \
  -Donnxruntime_ENABLE_THREADS=ON \
  -Donnxruntime_BUILD_EXTENDED_OPS=OFF \
  -Donnxruntime_ENABLE_TRAINING=OFF \
  -Donnxruntime_GTEST=OFF
cmake --build "$ORT_SRC/build_ohos" --parallel "$JOBS"

ORT_SO="$ORT_SRC/build_ohos/libonnxruntime.so"
[[ -f "$ORT_SO" ]] || { echo "error: $ORT_SO was not produced" >&2; exit 1; }
cp "$ORT_SO" "$STAGE/lib/libonnxruntime.so"

# --------------------------------------------------------------- sherpa-onnx
SHERPA_SRC="$BUILD_ROOT/sherpa-onnx"
if [[ ! -d "$SHERPA_SRC/.git" ]]; then
  echo "==> cloning sherpa-onnx $SHERPA_VERSION"
  git clone --depth 1 --branch "$SHERPA_VERSION" "$SHERPA_REPOSITORY" "$SHERPA_SRC"
fi

echo "==> building libsherpa-onnx-c-api.so (TTS off, so no espeak-ng)"
# The headers vendored in third_party/onnxruntime/include are the same 1.28.x
# release, which is what the Dart FFI was generated against.
export SHERPA_ONNXRUNTIME_INCLUDE_DIR="$HEADERS"
export SHERPA_ONNXRUNTIME_LIB_DIR="$STAGE/lib"
cmake -G Ninja -B "$SHERPA_SRC/build-ohos" -S "$SHERPA_SRC" \
  -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
  -DOHOS_ARCH=arm64-v8a \
  -DOHOS_STL=c++_static \
  -DOHOS_PLATFORM_LEVEL=24 \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=ON \
  -DSHERPA_ONNX_ENABLE_C_API=ON \
  -DSHERPA_ONNX_ENABLE_TTS=OFF \
  -DSHERPA_ONNX_ENABLE_JNI=OFF \
  -DSHERPA_ONNX_ENABLE_PORTAUDIO=OFF \
  -DSHERPA_ONNX_ENABLE_WEBSOCKET=OFF \
  -DSHERPA_ONNX_ENABLE_TESTS=OFF \
  -DSHERPA_ONNX_ENABLE_CHECK=OFF \
  -DSHERPA_ONNX_ENABLE_PYTHON=OFF \
  -DSHERPA_ONNX_ENABLE_GPU=OFF \
  -DSHERPA_ONNX_ENABLE_BINARIES=OFF
cmake --build "$SHERPA_SRC/build-ohos" --parallel "$JOBS"

for so in libsherpa-onnx-c-api.so libsherpa-onnx-cxx-api.so; do
  src="$SHERPA_SRC/build-ohos/lib/$so"
  [[ -f "$src" ]] || { echo "error: $so was not produced" >&2; exit 1; }
  cp "$src" "$STAGE/lib/$so"
done

# ------------------------------------------------------- licence and ABI gates
# espeak-ng is GPL-3.0. A plain -i espeak also matches "OfflineSpeaker", which is
# harmless, so match the phonemizer specifically.
if strings -a "$STAGE/lib/libsherpa-onnx-c-api.so" | grep -qi 'espeak[_-]ng'; then
  echo "ERROR: espeak-ng is still in libsherpa-onnx-c-api.so" >&2
  exit 1
fi
echo "ok: espeak-ng is not in libsherpa-onnx-c-api.so"

# The sandbox dlopen()s by bare filename and resolves DT_NEEDED by SONAME out of
# libs/arm64, so every library must carry an unversioned SONAME and there must be
# no libc++_shared.so to package (hence OHOS_STL=c++_static above).
for so in libonnxruntime.so libsherpa-onnx-c-api.so libsherpa-onnx-cxx-api.so; do
  soname="$(strings -a "$STAGE/lib/$so" | grep -E "^${so%%.so}\.so(\.[0-9]+)*$" \
    | grep -v "^${so}$" | head -1 || true)"
  if [[ -n "$soname" ]]; then
    echo "error: $so carries versioned SONAME '$soname'" >&2
    exit 1
  fi
  if strings -a "$STAGE/lib/$so" | grep -q "libc++_shared.so"; then
    echo "error: $so needs libc++_shared.so" >&2
    exit 1
  fi
done
echo "ok: unversioned SONAMEs, no libc++_shared.so"

# Strip: these ship inside the HAP and carry debug info otherwise (~44 MB of it).
for so in "$STAGE"/lib/*.so; do
  "$STRIP" --strip-unneeded "$so"
done

mkdir -p "$OUTPUT"
for so in libonnxruntime.so libsherpa-onnx-c-api.so libsherpa-onnx-cxx-api.so; do
  cp "$STAGE/lib/$so" "$OUTPUT/$so"
done

echo "Installed into $OUTPUT:"
ls -la "$OUTPUT" | awk 'NR>1 {printf "  %10s  %s\n", $5, $9}'
shasum -a 256 "$OUTPUT"/libonnxruntime.so "$OUTPUT"/libsherpa-onnx-c-api.so

if [[ "$KEEP_BUILD" != "true" ]]; then
  rm -rf "$ORT_SRC/build_ohos" "$SHERPA_SRC/build-ohos"
fi
echo "Done. Voice on HarmonyOS still needs a device run to confirm end to end."