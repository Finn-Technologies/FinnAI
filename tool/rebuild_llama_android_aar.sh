#!/usr/bin/env bash
set -euo pipefail

# Rebuild FinnAI's Android llama.cpp AAR from the exact source used by the
# pinned llama_cpp_dart Dart package. NDK r28+ emits 16 KB-compatible ELF
# LOAD segments by default. The finished AAR is rejected unless every shared
# library passes tool/verify_native_alignment.py.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_COMMIT="1a8c7563cb5382e23bcd20dc5720fc8d8099ec58"
LLAMA_COMMIT="d6d0ce8215a1c324e8de04b52f9dd65c5edc129f"
TAG="v0.9.0-dev.9"
REPOSITORY="https://github.com/netdur/llama_cpp_dart.git"
OUTPUT="$ROOT/android/app/libs/llama-cpp-dart.aar"
SOURCE=""
NDK="${ANDROID_NDK_ROOT:-}"
KEEP_BUILD=false

usage() {
  echo "Usage: $0 [--source PATH] [--ndk PATH] [--output PATH] [--keep-build]"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source) SOURCE="$2"; shift 2 ;;
    --ndk) NDK="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --keep-build) KEEP_BUILD=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ -z "$NDK" ]]; then
  SDK_ROOT="${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}"
  if [[ -d "$SDK_ROOT/ndk" ]]; then
    NDK="$(find "$SDK_ROOT/ndk" -mindepth 1 -maxdepth 1 -type d \
      | sort -V | tail -1)"
  fi
fi

if [[ ! -f "$NDK/source.properties" ]]; then
  echo "Android NDK not found. Pass --ndk or set ANDROID_NDK_ROOT." >&2
  exit 2
fi

NDK_REVISION="$(awk -F ' = ' '/Pkg.Revision/ { print $2 }' "$NDK/source.properties")"
NDK_MAJOR="${NDK_REVISION%%.*}"
if (( NDK_MAJOR < 28 )); then
  echo "NDK r28 or newer is required; found $NDK_REVISION." >&2
  exit 2
fi

BUILD_ROOT=""
cleanup() {
  if [[ -n "$BUILD_ROOT" && "$KEEP_BUILD" != "true" ]]; then
    rm -rf "$BUILD_ROOT"
  elif [[ -n "$BUILD_ROOT" ]]; then
    echo "Kept source and build tree at $BUILD_ROOT"
  fi
}
trap cleanup EXIT

if [[ -z "$SOURCE" ]]; then
  BUILD_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/finn-llama-source.XXXXXX")"
  SOURCE="$BUILD_ROOT/llama_cpp_dart"
  git clone --branch "$TAG" --recurse-submodules --depth 1 \
    --shallow-submodules "$REPOSITORY" "$SOURCE"
fi

if [[ "$(git -C "$SOURCE" rev-parse HEAD)" != "$PACKAGE_COMMIT" ]]; then
  echo "Source checkout does not match llama_cpp_dart $TAG ($PACKAGE_COMMIT)." >&2
  exit 1
fi
if [[ "$(git -C "$SOURCE/src/llama.cpp" rev-parse HEAD)" != "$LLAMA_COMMIT" ]]; then
  echo "llama.cpp submodule does not match the pinned commit $LLAMA_COMMIT." >&2
  exit 1
fi

SDK_ROOT="${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}"
if ! command -v cmake >/dev/null || ! command -v ninja >/dev/null; then
  CMAKE_BIN="$(find "$SDK_ROOT/cmake" -mindepth 2 -maxdepth 2 -type d \
    -name bin 2>/dev/null | sort -V | tail -1)"
  if [[ -z "$CMAKE_BIN" ]]; then
    echo "CMake and Ninja were not found in PATH or the Android SDK." >&2
    exit 2
  fi
  export PATH="$CMAKE_BIN:$PATH"
fi

echo "Building $TAG / llama.cpp ${LLAMA_COMMIT:0:8} with NDK $NDK_REVISION"
"$SOURCE/tool/build_android_aar.sh" \
  --ndk "$NDK" \
  --abi arm64-v8a \
  --clean

BUILT_AAR="$SOURCE/build/android/llama-cpp-dart.aar"
python3 "$ROOT/tool/verify_native_alignment.py" "$BUILT_AAR"

mkdir -p "$(dirname "$OUTPUT")"
cp "$BUILT_AAR" "$OUTPUT"
echo "Installed source-built AAR at $OUTPUT"
shasum -a 256 "$OUTPUT"
