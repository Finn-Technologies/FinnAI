#!/usr/bin/env bash
set -euo pipefail

# Fetch FinnAI's iOS llama.cpp runtime from the exact release asset built
# from the pinned llama_cpp_dart Dart package (v0.9.0-dev.9). The
# xcframework is embedded via ios/LlamaCpp/llama_cpp.podspec (Embed & Sign);
# app code resolves its symbols from the running process
# (LlamaEngine.spawnFromProcess on iOS).
#
# The binary is intentionally NOT committed (see ios/.gitignore). Run this
# once per checkout.
#
# Follow-up: build from source with tool/llama_android_native.patch applied
# (repack cache, thread affinity, GDN fast path) the way
# tool/rebuild_llama_android_aar.sh does for Android, once iOS inference is
# verified against this prebuilt baseline.
#
# Usage: tool/rebuild_llama_ios_xcframework.sh [--keep-zip]

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TAG="v0.9.0-dev.9"
ASSET="llama-xcframework.zip"
BASE_URL="https://github.com/netdur/llama_cpp_dart/releases/download/$TAG"
EXPECTED_SHA="9961403cf5936a380c698a3509f3377f830a9a586d44383970e6f9f010dd8af1"
DEST="$ROOT/ios/LlamaCpp"
KEEP_ZIP=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --keep-zip) KEEP_ZIP=true; shift ;;
    -h|--help) grep -E '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

mkdir -p "$DEST"
cd "$DEST"

if [[ ! -f "$ASSET" ]]; then
  echo "Downloading $TAG/$ASSET"
  curl -sSL -o "$ASSET" "$BASE_URL/$ASSET"
fi

ACTUAL_SHA="$(shasum -a 256 "$ASSET" | awk '{ print $1 }')"
if [[ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]]; then
  echo "SHA-256 mismatch for $ASSET:" >&2
  echo "  expected $EXPECTED_SHA" >&2
  echo "  actual   $ACTUAL_SHA" >&2
  exit 1
fi

echo "SHA-256 verified, unpacking"
unzip -q -o "$ASSET"
if [[ ! -d "llama.xcframework" ]]; then
  echo "llama.xcframework missing after unpack" >&2
  exit 1
fi

if [[ "$KEEP_ZIP" != "true" ]]; then
  rm -f "$ASSET"
fi

echo "Installed iOS runtime at $DEST/llama.xcframework"
ls -1 "$DEST/llama.xcframework"
