#!/usr/bin/env bash
set -euo pipefail

# Make the Flutter OHOS engine HAR compile against the HarmonyOS 6.1.1 (API 24)
# SDK, the newest Release SDK the public Command Line Tools ship.
#
# Why this exists
# ---------------
# The engine HAR the fork downloads
# (bin/cache/artifacts/engine/ohos-arm64/flutter.har) carries ArkTS sources, and
# one of them - src/main/ets/plugin/editing/OhosAutoFillHelper.ets - annotates
# types that only exist from HarmonyOS 7 (API 26): autoFillManager.FillRequest,
# .AutoFillCallback, .ViewData, .FillFailureResult, .SaveRequest, .AutoFillType,
# .AutoFillTriggerType, and the requestAutoFill() overload. ArkTS resolves type
# annotations at compile time, so `hvigorw assembleHap` reports 14 errors in
# that one file and no app built with this fork can be packaged against API 24.
#
# The upstream file already short-circuits both public entry points when
# `deviceInfo.sdkApiVersion < AUTOFILL_SUPPORT_API` (26), i.e. the API-26
# surface is unreachable on API 24 anyway. The patch therefore changes only
# compile-time typing: local aliases replace the API-26 type names and the two
# API-26-only calls go through an ESObject view of the namespace. No behaviour
# changes on any API level.
#
# This mirrors how the repo already patches vendored native code: see
# tool/rebuild_llama_android_aar.sh + tool/llama_android_build.patch. The
# patch is applied to the Flutter SDK's engine cache, never to app source, and
# is safe to re-run. Delete bin/cache/artifacts/engine/ohos-* and re-run this
# script if the fork's cache is ever rebuilt from scratch.
#
# Once the fork targets API 26 (or the SDK ships API 26), delete this script and
# tool/ohos_engine_har_api24.patch.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATCH_FILE="$ROOT/tool/ohos_engine_har_api24.patch"
FLUTTER_ROOT="${FLUTTER_ROOT:-}"
MARKER="FINN_API24_AUTOFILL_SHIM"

usage() {
  cat <<'EOF'
Usage: $0 [--flutter-root PATH] [--check]

  --flutter-root PATH  Flutter OHOS fork checkout (default: `flutter --version`
                       cache root, or $FLUTTER_ROOT). Only its
                       bin/cache/artifacts/engine/ohos-*/flutter.har is touched.
  --check              Report whether each engine HAR is already patched.
                       Exits non-zero if any is unpatched. Changes nothing.
EOF
}

CHECK_ONLY=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --flutter-root) FLUTTER_ROOT="$2"; shift 2 ;;
    --check) CHECK_ONLY=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ -z "$FLUTTER_ROOT" ]]; then
  FLUTTER_BIN="$(command -v flutter || true)"
  if [[ -z "$FLUTTER_BIN" ]]; then
    echo "flutter not found on PATH. Pass --flutter-root PATH." >&2
    exit 2
  fi
  # <root>/bin/flutter -> <root>
  FLUTTER_ROOT="$(cd "$(dirname "$FLUTTER_BIN")/.." && pwd)"
fi

ENGINE_DIR="$FLUTTER_ROOT/bin/cache/artifacts/engine"
if [[ ! -d "$ENGINE_DIR" ]]; then
  echo "No Flutter engine artifacts at $ENGINE_DIR." >&2
  echo "Run 'flutter precache --ohos' (or any ohos build) first." >&2
  exit 2
fi
if [[ ! -f "$PATCH_FILE" ]]; then
  echo "Missing $PATCH_FILE" >&2
  exit 2
fi

shopt -s nullglob
HARS=("$ENGINE_DIR"/ohos-*/flutter.har)
shopt -u nullglob
if [[ ${#HARS[@]} -eq 0 ]]; then
  echo "No ohos-*/flutter.har under $ENGINE_DIR." >&2
  echo "Run 'flutter precache --ohos' first." >&2
  exit 2
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/finn-ohos-har.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

patched_all=true
for har in "${HARS[@]}"; do
  rel="${har#"$ENGINE_DIR"/}"
  # Materialise the member into a file rather than piping into `grep -q`: grep
  # exits on the first match, which SIGPIPEs tar, and `set -o pipefail` would
  # then report an already-patched HAR as unpatched.
  if ! tar -xzf "$har" -C "$WORK" package/src/main/ets/plugin/editing/OhosAutoFillHelper.ets \
      2>/dev/null; then
    patched_all=false
    if $CHECK_ONLY; then
      echo "MISSING  $rel (no OhosAutoFillHelper.ets in the HAR)"
    else
      echo "skipped  $rel (no OhosAutoFillHelper.ets in the HAR)"
    fi
    continue
  fi
  if grep -q "$MARKER" "$WORK/package/src/main/ets/plugin/editing/OhosAutoFillHelper.ets"; then
    echo "ok       $rel (already patched)"
    continue
  fi
  rm -rf "$WORK/package"
  patched_all=false
  if $CHECK_ONLY; then
    echo "MISSING  $rel"
    continue
  fi

  mkdir -p "$WORK/package"
  tar -xzf "$har" -C "$WORK/package"

  if ! (cd "$WORK/package" && patch -p1 --forward --silent < "$PATCH_FILE"); then
    echo "  $rel: patch did not apply; the engine HAR changed shape." >&2
    echo "  Re-check tool/ohos_engine_har_api24.patch against the new fork." >&2
    exit 1
  fi

  # Repack with the same layout the tool copies to ohos/har/flutter.har.
  (cd "$WORK/package" && tar -czf "$WORK/repack.har" package)
  mv "$WORK/repack.har" "$har"
  echo "patched  $rel"
done

if $CHECK_ONLY && ! $patched_all; then
  echo >&2
  echo "Run 'bash tool/patch_ohos_engine_har.sh' before building the HAP." >&2
  exit 1
fi