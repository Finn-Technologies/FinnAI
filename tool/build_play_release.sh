#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

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
FINN_SUPPORT_EMAIL="${FINN_SUPPORT_EMAIL:-}"
FINN_REPORT_ENDPOINT="${FINN_REPORT_ENDPOINT:-https://finn-org.vercel.app/v1/reports}"

require_https_url FINN_PRIVACY_POLICY_URL
require_https_url FINN_TERMS_URL
require_https_url FINN_SUPPORT_URL
require_https_url FINN_REPORT_ENDPOINT

[[ "$FINN_REPORT_ENDPOINT" == */v1/reports ]] ||
  fail "FINN_REPORT_ENDPOINT must end with /v1/reports."

if [ -n "$FINN_SUPPORT_EMAIL" ] &&
    [[ ! "$FINN_SUPPORT_EMAIL" =~ ^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$ ]]; then
  fail "FINN_SUPPORT_EMAIL must be a valid monitored email address."
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

REPORT_HEALTH_URL="${FINN_REPORT_ENDPOINT%/v1/reports}/health"
echo "Checking AI reporting service health..."
REPORT_HEALTH_RESPONSE="$(
  curl --fail --silent --show-error --location --max-time 15 \
    "$REPORT_HEALTH_URL"
)"
[[ "$REPORT_HEALTH_RESPONSE" == *'"status":"ok"'* ]] ||
  fail "Reporting service health check did not return {\"status\":\"ok\"}."

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
  --dart-define="FINN_REPORT_ENDPOINT=$FINN_REPORT_ENDPOINT"

echo
echo "Publishable AAB:"
echo "build/app/outputs/bundle/release/app-release.aab"
