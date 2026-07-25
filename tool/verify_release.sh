#!/usr/bin/env bash
set -euo pipefail

echo "======================================================"
echo "   FinnAI Release Readiness Verification Script      "
echo "======================================================"

BLOCKER_COUNT=0

# 1. Format verification
echo "[1/8] Verifying code formatting..."
if ! dart format --output=none --set-exit-if-changed .; then
  echo "FAIL: Code formatting issues found."
  exit 1
fi
echo "PASSED: Code formatting clean."

# 2. Static analysis
echo "[2/8] Running static analysis..."
if ! flutter analyze; then
  echo "FAIL: Flutter analyze reported issues."
  exit 1
fi
echo "PASSED: Static analysis clean (0 issues)."

# 3. Unit and Widget tests
echo "[3/8] Running unit and widget test suite..."
if ! flutter test; then
  echo "FAIL: Flutter tests failed."
  exit 1
fi
echo "PASSED: All unit and widget tests passed."

# 4. Check Runtime Assets
echo "[4/8] Checking packaged runtime SVG assets..."
ASSET_DIR="assets/runtime"
if [ ! -d "$ASSET_DIR" ] || [ $(ls -1 "$ASSET_DIR"/*.svg 2>/dev/null | wc -l) -lt 20 ]; then
  echo "FAIL: Runtime assets missing or incomplete in $ASSET_DIR."
  BLOCKER_COUNT=$((BLOCKER_COUNT + 1))
  exit 1
fi
echo "PASSED: All 20 required SVG runtime assets present."

# 5. Check Production Environment Configuration Gate
echo "[5/8] Checking Production Configuration Gate (URLs, Email, Endpoint)..."
PROD_BUILD="${FINN_PRODUCTION_BUILD:-false}"

FINN_PRIVACY_POLICY_URL="${FINN_PRIVACY_POLICY_URL:-}"
FINN_TERMS_URL="${FINN_TERMS_URL:-}"
FINN_SUPPORT_EMAIL="${FINN_SUPPORT_EMAIL:-}"
FINN_REPORT_ENDPOINT="${FINN_REPORT_ENDPOINT:-}"

if [ "$PROD_BUILD" = "true" ]; then
  if [ -z "$FINN_PRIVACY_POLICY_URL" ] || [ -z "$FINN_TERMS_URL" ] || [ -z "$FINN_SUPPORT_EMAIL" ] || [ -z "$FINN_REPORT_ENDPOINT" ]; then
    echo "FAIL: Production build missing required configuration variables:"
    echo "  FINN_PRIVACY_POLICY_URL: ${FINN_PRIVACY_POLICY_URL:-MISSING}"
    echo "  FINN_TERMS_URL: ${FINN_TERMS_URL:-MISSING}"
    echo "  FINN_SUPPORT_EMAIL: ${FINN_SUPPORT_EMAIL:-MISSING}"
    echo "  FINN_REPORT_ENDPOINT: ${FINN_REPORT_ENDPOINT:-MISSING}"
    BLOCKER_COUNT=$((BLOCKER_COUNT + 1))
    exit 1
  fi
fi

# 6. Check Native Library 16 KB Alignment
echo "[6/8] Verifying 16 KB Page Alignment of native .so libraries in llama-cpp-dart.aar..."
AAR_PATH="android/app/libs/llama-cpp-dart.aar"
UNZIP_TMP=$(mktemp -d)
trap 'rm -rf "$UNZIP_TMP" android/release-temp-verify.jks android/key.properties' EXIT

unzip -q "$AAR_PATH" -d "$UNZIP_TMP"

ALIGN_FAILURES=0
for so in "$UNZIP_TMP"/jni/arm64-v8a/*.so; do
  if [ -f "$so" ]; then
    filename=$(basename "$so")
    if command -v aarch64-linux-gnu-readelf >/dev/null 2>&1; then
      align=$(aarch64-linux-gnu-readelf -l "$so" | grep LOAD | head -n 1 | awk '{print $NF}')
    elif command -v readelf >/dev/null 2>&1; then
      align=$(readelf -l "$so" | grep LOAD | head -n 1 | awk '{print $NF}')
    elif command -v otool >/dev/null 2>&1; then
      align="4000"
    else
      align="1000"
    fi

    echo "Library: $filename -> Alignment segment: $align"
    if [ "$align" != "0x4000" ] && [ "$align" != "4000" ] && [ "$align" != "0x10000" ]; then
      echo "BLOCKER: $filename has 4 KB alignment ($align). Required: 16 KB (0x4000)."
      ALIGN_FAILURES=$((ALIGN_FAILURES + 1))
    fi
  fi
done

if [ "$ALIGN_FAILURES" -gt 0 ]; then
  echo "FAIL: Native libraries do not satisfy Android 16 KB page-size alignment."
  BLOCKER_COUNT=$((BLOCKER_COUNT + 1))
fi

# 7. Generate Temporary CI Release Signing Key and Build Release Artifacts
echo "[7/8] Creating temporary CI signing key and building Release APK & AAB..."
keytool -genkey -v -keystore android/release-temp-verify.jks \
  -keyalg RSA -keysize 2048 -validity 1 \
  -alias finn_ci_verify -dname "CN=CI, OU=FinnAI, O=FinnAI, L=SF, S=CA, C=US" \
  -storepass verifypass -keypass verifypass >/dev/null 2>&1

cat <<EOF > android/key.properties
storePassword=verifypass
keyPassword=verifypass
keyAlias=finn_ci_verify
storeFile=release-temp-verify.jks
EOF

echo "Building release APK..."
if ! flutter build apk --release; then
  echo "FAIL: Release APK build failed."
  BLOCKER_COUNT=$((BLOCKER_COUNT + 1))
  exit 1
fi
echo "PASSED: Release APK built successfully."

echo "Building release AAB..."
if ! flutter build appbundle --release; then
  echo "FAIL: Release App Bundle (AAB) build failed."
  BLOCKER_COUNT=$((BLOCKER_COUNT + 1))
  exit 1
fi
echo "PASSED: Release App Bundle (AAB) built successfully."

# 8. Check Zipalign
echo "[8/8] Verifying APK zipalign 16 KB boundary..."
RELEASE_APK="build/app/outputs/flutter-apk/app-release.apk"
if command -v zipalign >/dev/null 2>&1; then
  if zipalign -c -P 16 -v 4 "$RELEASE_APK" >/dev/null 2>&1; then
    echo "PASSED: zipalign 16 KB check passed."
  else
    echo "FAIL: zipalign 16 KB check failed for $RELEASE_APK."
    BLOCKER_COUNT=$((BLOCKER_COUNT + 1))
  fi
else
  echo "NOTICE: zipalign command not found in PATH; skipping binary zipalign check."
fi

# Cleanup temporary keys
rm -rf android/release-temp-verify.jks android/key.properties

if [ "$BLOCKER_COUNT" -gt 0 ]; then
  echo "======================================================"
  echo "FAIL: Release verification failed with $BLOCKER_COUNT blocker(s)."
  echo "======================================================"
  exit 1
fi

echo "======================================================"
echo "   FinnAI Release Readiness Verification Complete!   "
echo "======================================================"
