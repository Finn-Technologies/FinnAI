#!/usr/bin/env bash
set -euo pipefail

echo "======================================================"
echo "   FinnAI Release Readiness Verification Script      "
echo "======================================================"

BLOCKER_COUNT=0
CREATED_FILES=()

cleanup() {
  echo "Performing verification cleanup..."
  if [ ${#CREATED_FILES[@]} -gt 0 ]; then
    for file in "${CREATED_FILES[@]}"; do
      if [ -e "$file" ]; then
        rm -rf "$file"
      fi
    done
  fi

  if [ -f "android/key.properties.bak" ]; then
    mv "android/key.properties.bak" "android/key.properties"
  fi
}
trap cleanup EXIT

# Backup existing key.properties if present
if [ -f "android/key.properties" ]; then
  cp "android/key.properties" "android/key.properties.bak"
fi

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

# 6. Check Native Library 16 KB Alignment using Real Python ELF Parser
echo "[6/8] Verifying 16 KB Page Alignment of native .so libraries..."
AAR_PATH="android/app/libs/llama-cpp-dart.aar"
UNZIP_TMP=$(mktemp -d)
CREATED_FILES+=("$UNZIP_TMP")

unzip -q "$AAR_PATH" -d "$UNZIP_TMP"

ALIGN_STATUS=0
python3 - "$UNZIP_TMP/jni/arm64-v8a" << 'PYEOF' || ALIGN_STATUS=$?
import sys, glob, struct, os

so_dir = sys.argv[1]
so_files = glob.glob(os.path.join(so_dir, "*.so"))
if not so_files:
    print("FAIL: No .so files found in extracted AAR!")
    sys.exit(1)

has_blocker = False
for so_path in so_files:
    filename = os.path.basename(so_path)
    with open(so_path, 'rb') as f:
        data = f.read(64)
        if len(data) < 64 or data[:4] != b'\x7fELF':
            print(f"FAIL: {filename} is not a valid ELF file")
            has_blocker = True
            continue

        e_phoff = struct.unpack('<Q', data[32:40])[0]
        e_phentsize = struct.unpack('<H', data[54:56])[0]
        e_phnum = struct.unpack('<H', data[56:58])[0]

        f.seek(e_phoff)
        min_align = float('inf')
        load_count = 0
        for _ in range(e_phnum):
            ph = f.read(e_phentsize)
            if len(ph) < e_phentsize:
                break
            p_type = struct.unpack('<I', ph[0:4])[0]
            p_align = struct.unpack('<Q', ph[48:56])[0]
            if p_type == 1:  # PT_LOAD
                load_count += 1
                if p_align < min_align:
                    min_align = p_align

        print(f"Library {filename} (PT_LOAD count: {load_count}): Min alignment = 0x{min_align:x} ({min_align} bytes)")
        if min_align < 0x4000:
            print(f"BLOCKER: {filename} segment alignment 0x{min_align:x} is below 16 KB (0x4000).")
            has_blocker = True

if has_blocker:
    sys.exit(1)
PYEOF

if [ "$ALIGN_STATUS" -ne 0 ]; then
  echo "FAIL: Native libraries do not satisfy Android 16 KB page-size alignment."
  BLOCKER_COUNT=$((BLOCKER_COUNT + 1))
fi

# 7. Generate Temporary CI Release Signing Key and Build Release Artifacts
echo "[7/8] Creating temporary CI signing key and building Release APK & AAB..."

KEYTOOL_BIN="keytool"
if [ -f "/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool" ]; then
  KEYTOOL_BIN="/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool"
fi

TEMP_JKS="android/app/release-temp-verify.jks"
CREATED_FILES+=("$TEMP_JKS" "android/key.properties")

"$KEYTOOL_BIN" -genkey -v -keystore "$TEMP_JKS" \
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

ZIPALIGN_BIN="zipalign"
if [ -f "$HOME/Library/Android/sdk/build-tools/36.0.0/zipalign" ]; then
  ZIPALIGN_BIN="$HOME/Library/Android/sdk/build-tools/36.0.0/zipalign"
elif [ -f "$HOME/Library/Android/sdk/build-tools/35.0.0/zipalign" ]; then
  ZIPALIGN_BIN="$HOME/Library/Android/sdk/build-tools/35.0.0/zipalign"
fi

if command -v "$ZIPALIGN_BIN" >/dev/null 2>&1 || [ -x "$ZIPALIGN_BIN" ]; then
  if "$ZIPALIGN_BIN" -c -P 16 -v 4 "$RELEASE_APK" >/dev/null 2>&1; then
    echo "PASSED: zipalign 16 KB check passed."
  else
    echo "FAIL: zipalign 16 KB check failed for $RELEASE_APK."
    BLOCKER_COUNT=$((BLOCKER_COUNT + 1))
  fi
else
  echo "NOTICE: zipalign command not found in PATH; skipping binary zipalign check."
fi

if [ "$BLOCKER_COUNT" -gt 0 ]; then
  echo "======================================================"
  echo "FAIL: Release verification failed with $BLOCKER_COUNT blocker(s)."
  echo "======================================================"
  exit 1
fi

echo "======================================================"
echo "   FinnAI Release Readiness Verification Complete!   "
echo "======================================================"
