#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# Files/directories created by this script and removed during cleanup.
# Bash 3.2 treats an empty array expansion as unbound under `set -u`,
# so a harmless sentinel keeps early-failure cleanup reliable on macOS.
CREATED_FILES=("")

cleanup() {
  for file in "${CREATED_FILES[@]}"; do
    if [ -n "$file" ] && [ -e "$file" ]; then
      rm -rf "$file"
    fi
  done
}
trap cleanup EXIT

# ── OpenHarmony (HOS) SDK stub ────────────────────────────────────────────────
# This checkout's Flutter is the OpenHarmony fork and the repository ships an
# ohos/ project, so every flutter command runs the ohos tooling step first.
# With HOS_SDK_HOME unset that step aborts with "No Hmos SDK found.", and the
# usual --no-pub workaround skips both that step and Android plugin registrant
# generation — producing an AAB that crashes at launch with a
# ClassNotFoundException for io.flutter.plugins.GeneratedPluginRegistrant.
# A minimal stub satisfies the tooling's SDK validation without installing a
# real OHOS SDK: HmosSdk.validApi10SdkDirectory only checks that
# $HOS_SDK_HOME/hmscore and $HOS_SDK_HOME/openharmony exist.
setup_hos_sdk_stub() {
  HOS_SDK_STUB_DIR=$(mktemp -d)
  mkdir -p "${HOS_SDK_STUB_DIR}/hmscore" "${HOS_SDK_STUB_DIR}/openharmony"
  export HOS_SDK_HOME="${HOS_SDK_STUB_DIR}"
  CREATED_FILES+=("${HOS_SDK_STUB_DIR}")
  echo "Using stub HOS SDK at ${HOS_SDK_STUB_DIR}"
}

setup_hos_sdk_stub

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

require_value() {
  local name="$1"
  local value="${!name:-}"
  [ -n "$value" ] || fail "$name is required for a Play production build."
}

require_https_url() {
  local name="$1"
  local value="${!name}"
  [[ "$value" =~ ^https://[^[:space:]]+$ ]] ||
    fail "$name must be a public HTTPS URL."
  [[ "$value" != *".invalid"* ]] ||
    fail "$name cannot use a reserved .invalid domain."
}

FINN_PRIVACY_POLICY_URL="${FINN_PRIVACY_POLICY_URL:-https://finn-org.vercel.app/privacy}"
FINN_TERMS_URL="${FINN_TERMS_URL:-https://finn-org.vercel.app/terms}"
FINN_SUPPORT_URL="${FINN_SUPPORT_URL:-https://finn-org.vercel.app/support}"
FINN_SUPPORT_EMAIL="${FINN_SUPPORT_EMAIL:-finn_org@proton.me}"
FINN_REPORT_EMAIL="${FINN_REPORT_EMAIL:-finn_org@proton.me}"

require_https_url FINN_PRIVACY_POLICY_URL
require_https_url FINN_TERMS_URL
require_https_url FINN_SUPPORT_URL

if [ -n "$FINN_SUPPORT_EMAIL" ] &&
    [[ ! "$FINN_SUPPORT_EMAIL" =~ ^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$ ]]; then
  fail "FINN_SUPPORT_EMAIL must be a valid monitored email address."
fi
if [[ ! "$FINN_REPORT_EMAIL" =~ ^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$ ]]; then
  fail "FINN_REPORT_EMAIL must be a valid monitored email address."
fi

if [ ! -f android/key.properties ]; then
  missing_signing=()
  for name in KEYSTORE_PATH KEYSTORE_PASSWORD KEY_ALIAS KEY_PASSWORD; do
    [ -n "${!name:-}" ] || missing_signing+=("$name")
  done
  if [ "${#missing_signing[@]}" -gt 0 ]; then
    fail "Release signing is not configured. Add android/key.properties or set: ${missing_signing[*]}"
  fi
  [ -f "$KEYSTORE_PATH" ] || fail "KEYSTORE_PATH does not point to an existing file."
fi

command -v curl >/dev/null 2>&1 ||
  fail "curl is required to verify public production endpoints."

echo "Checking hosted privacy policy and terms..."
curl --fail --silent --show-error --location --max-time 15 \
  --output /dev/null "$FINN_PRIVACY_POLICY_URL"
curl --fail --silent --show-error --location --max-time 15 \
  --output /dev/null "$FINN_TERMS_URL"
curl --fail --silent --show-error --location --max-time 15 \
  --output /dev/null "$FINN_SUPPORT_URL"

echo "Running production release verification..."
FINN_PRODUCTION_BUILD=true \
  ./tool/verify_release.sh

echo "Building final Play App Bundle with the configured upload key..."
flutter build appbundle \
  --release \
  --target-platform android-arm64 \
  --dart-define="FINN_PRIVACY_POLICY_URL=$FINN_PRIVACY_POLICY_URL" \
  --dart-define="FINN_TERMS_URL=$FINN_TERMS_URL" \
  --dart-define="FINN_SUPPORT_URL=$FINN_SUPPORT_URL" \
  --dart-define="FINN_SUPPORT_EMAIL=$FINN_SUPPORT_EMAIL" \
  --dart-define="FINN_REPORT_EMAIL=$FINN_REPORT_EMAIL"

echo
echo "Publishable AAB:"
echo "build/app/outputs/bundle/release/app-release.aab"
