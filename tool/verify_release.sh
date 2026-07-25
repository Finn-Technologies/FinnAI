#!/usr/bin/env bash
set -euo pipefail

echo "======================================================"
echo "   FinnAI Release Readiness Verification Script      "
echo "======================================================"

BLOCKER_COUNT=0
CREATED_FILES=()

# ── Unique backup so we never collide with a pre-existing .bak file ──────────
KEY_PROPS="android/key.properties"
KEY_PROPS_BAK=""   # filled in only if we actually back up

cleanup() {
  echo "Performing verification cleanup..."
  if [ ${#CREATED_FILES[@]} -gt 0 ]; then
    for file in "${CREATED_FILES[@]}"; do
      if [ -e "$file" ]; then
        rm -rf "$file"
      fi
    done
  fi
  # Restore original key.properties from our unique backup
  if [ -n "$KEY_PROPS_BAK" ] && [ -f "$KEY_PROPS_BAK" ]; then
    mv "$KEY_PROPS_BAK" "$KEY_PROPS"
  fi
}
trap cleanup EXIT

# Backup existing key.properties with a unique name so we never overwrite
# a pre-existing .bak file created by another process or a prior run.
if [ -f "$KEY_PROPS" ]; then
  KEY_PROPS_BAK=$(mktemp "${KEY_PROPS}.bak.XXXXXX")
  cp "$KEY_PROPS" "$KEY_PROPS_BAK"
  CREATED_FILES+=("$KEY_PROPS_BAK")
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
if [ ! -d "$ASSET_DIR" ] || [ "$(ls -1 "$ASSET_DIR"/*.svg 2>/dev/null | wc -l)" -lt 20 ]; then
  echo "FAIL: Runtime assets missing or incomplete in $ASSET_DIR."
  BLOCKER_COUNT=$((BLOCKER_COUNT + 1))
  exit 1
fi
echo "PASSED: All 20 required SVG runtime assets present."

# 5. Production Configuration Gate
echo "[5/8] Checking Production Configuration Gate (URLs, Email, Endpoint)..."
PROD_BUILD="${FINN_PRODUCTION_BUILD:-false}"

FINN_PRIVACY_POLICY_URL="${FINN_PRIVACY_POLICY_URL:-}"
FINN_TERMS_URL="${FINN_TERMS_URL:-}"
FINN_SUPPORT_EMAIL="${FINN_SUPPORT_EMAIL:-}"
FINN_REPORT_ENDPOINT="${FINN_REPORT_ENDPOINT:-}"

# Build both APK and AAB passing configuration values via --dart-define so the
# compiled binary actually contains them rather than empty defaults.
DART_DEFINES=(
  "--dart-define=FINN_PRIVACY_POLICY_URL=${FINN_PRIVACY_POLICY_URL}"
  "--dart-define=FINN_TERMS_URL=${FINN_TERMS_URL}"
  "--dart-define=FINN_SUPPORT_EMAIL=${FINN_SUPPORT_EMAIL}"
  "--dart-define=FINN_REPORT_ENDPOINT=${FINN_REPORT_ENDPOINT}"
)

if [ "$PROD_BUILD" = "true" ]; then
  if [ -z "$FINN_PRIVACY_POLICY_URL" ] || [ -z "$FINN_TERMS_URL" ] || \
     [ -z "$FINN_SUPPORT_EMAIL" ] || [ -z "$FINN_REPORT_ENDPOINT" ]; then
    echo "FAIL: Production build missing required configuration variables:"
    echo "  FINN_PRIVACY_POLICY_URL: ${FINN_PRIVACY_POLICY_URL:-MISSING}"
    echo "  FINN_TERMS_URL: ${FINN_TERMS_URL:-MISSING}"
    echo "  FINN_SUPPORT_EMAIL: ${FINN_SUPPORT_EMAIL:-MISSING}"
    echo "  FINN_REPORT_ENDPOINT: ${FINN_REPORT_ENDPOINT:-MISSING}"
    BLOCKER_COUNT=$((BLOCKER_COUNT + 1))
    exit 1
  fi
fi

# 6. Generate Temporary CI Release Signing Key and Build Release Artifacts
echo "[6/8] Creating temporary CI signing key and building Release APK & AAB..."

KEYTOOL_BIN="keytool"
if [ -f "/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool" ]; then
  KEYTOOL_BIN="/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool"
fi

# Create unique temp keystore inside android/app/ so storeFile relative path resolves correctly
TEMP_JKS=$(mktemp "android/app/release-temp-verify.XXXXXX.jks")
CREATED_FILES+=("$TEMP_JKS" "$KEY_PROPS")
TEMP_JKS_BASENAME=$(basename "$TEMP_JKS")

"$KEYTOOL_BIN" -genkey -v -keystore "$TEMP_JKS" \
  -keyalg RSA -keysize 2048 -validity 1 \
  -alias finn_ci_verify -dname "CN=CI, OU=FinnAI, O=FinnAI, L=SF, S=CA, C=US" \
  -storepass verifypass -keypass verifypass >/dev/null 2>&1

cat <<EOF > "$KEY_PROPS"
storePassword=verifypass
keyPassword=verifypass
keyAlias=finn_ci_verify
storeFile=${TEMP_JKS_BASENAME}
EOF

RELEASE_APK="build/app/outputs/flutter-apk/app-release.apk"

echo "Building release APK..."
if ! flutter build apk --release "${DART_DEFINES[@]}"; then
  echo "FAIL: Release APK build failed."
  BLOCKER_COUNT=$((BLOCKER_COUNT + 1))
  exit 1
fi
echo "PASSED: Release APK built successfully."

echo "Building release AAB..."
if ! flutter build appbundle --release "${DART_DEFINES[@]}"; then
  echo "FAIL: Release App Bundle (AAB) build failed."
  BLOCKER_COUNT=$((BLOCKER_COUNT + 1))
  exit 1
fi
echo "PASSED: Release App Bundle (AAB) built successfully."

# Verify dart-defines actually reached the compiled APK by checking the values
# are embedded as UTF-8 strings. Only run when non-empty so this is meaningful.
if [ -n "$FINN_PRIVACY_POLICY_URL" ]; then
  if strings "$RELEASE_APK" 2>/dev/null | grep -qF "$FINN_PRIVACY_POLICY_URL"; then
    echo "PASSED: FINN_PRIVACY_POLICY_URL found embedded in release APK."
  else
    echo "FAIL: FINN_PRIVACY_POLICY_URL NOT found in release APK — dart-define may not have been passed correctly."
    BLOCKER_COUNT=$((BLOCKER_COUNT + 1))
  fi
fi

# 7. zipalign — missing binary is a failure, not a notice
echo "[7/8] Verifying APK zipalign 16 KB boundary..."

ZIPALIGN_BIN=""
for candidate in \
    "$HOME/Library/Android/sdk/build-tools/36.0.0/zipalign" \
    "$HOME/Library/Android/sdk/build-tools/35.0.0/zipalign" \
    "$HOME/Library/Android/sdk/build-tools/34.0.0/zipalign" \
    "$(command -v zipalign 2>/dev/null || true)"; do
  if [ -x "$candidate" ]; then
    ZIPALIGN_BIN="$candidate"
    break
  fi
done

if [ -z "$ZIPALIGN_BIN" ]; then
  echo "FAIL: zipalign not found. Install Android build-tools and ensure it is on PATH."
  BLOCKER_COUNT=$((BLOCKER_COUNT + 1))
elif "$ZIPALIGN_BIN" -c -P 16 -v 4 "$RELEASE_APK" >/dev/null 2>&1; then
  echo "PASSED: zipalign 16 KB check passed."
else
  echo "FAIL: zipalign 16 KB check failed for $RELEASE_APK."
  BLOCKER_COUNT=$((BLOCKER_COUNT + 1))
fi

# 8. Python ELF parser — run against EVERY .so in the packaged APK lib/arm64-v8a/
# (not only the source AAR). This catches any additional bundled libraries.
echo "[8/8] Verifying 16 KB page alignment of ALL packaged native libraries..."

APK_UNZIP_TMP=$(mktemp -d)
CREATED_FILES+=("$APK_UNZIP_TMP")

unzip -q "$RELEASE_APK" -d "$APK_UNZIP_TMP"

APK_SO_DIR="$APK_UNZIP_TMP/lib/arm64-v8a"
if [ ! -d "$APK_SO_DIR" ]; then
  echo "FAIL: No lib/arm64-v8a directory found in release APK."
  BLOCKER_COUNT=$((BLOCKER_COUNT + 1))
else
  ALIGN_STATUS=0
  python3 - "$APK_SO_DIR" << 'PYEOF' || ALIGN_STATUS=$?
import sys, glob, struct, os

so_dir = sys.argv[1]
so_files = glob.glob(os.path.join(so_dir, "*.so"))
if not so_files:
    print("FAIL: No .so files found in packaged APK lib/arm64-v8a!")
    sys.exit(1)

has_blocker = False
for so_path in sorted(so_files):
    filename = os.path.basename(so_path)
    with open(so_path, 'rb') as f:
        header = f.read(64)
        if len(header) < 64 or header[:4] != b'\x7fELF':
            print(f"FAIL: {filename} is not a valid ELF file")
            has_blocker = True
            continue

        e_phoff    = struct.unpack('<Q', header[32:40])[0]
        e_phentsize = struct.unpack('<H', header[54:56])[0]
        e_phnum    = struct.unpack('<H', header[56:58])[0]

        f.seek(e_phoff)
        min_align = None
        load_count = 0
        for _ in range(e_phnum):
            ph = f.read(e_phentsize)
            if len(ph) < e_phentsize:
                break
            p_type  = struct.unpack('<I', ph[0:4])[0]
            p_align = struct.unpack('<Q', ph[48:56])[0]
            if p_type == 1:   # PT_LOAD
                load_count += 1
                if min_align is None or p_align < min_align:
                    min_align = p_align

    if min_align is None:
        print(f"SKIP:    {filename} — no PT_LOAD segments")
        continue

    status = "OK" if min_align >= 0x4000 else "BLOCKER"
    print(f"{status}: {filename} (PT_LOAD x{load_count}) min align = 0x{min_align:x}")
    if min_align < 0x4000:
        has_blocker = True

if has_blocker:
    sys.exit(1)
PYEOF

  if [ "$ALIGN_STATUS" -ne 0 ]; then
    echo "FAIL: One or more packaged native libraries do not satisfy Android 16 KB page-size alignment."
    BLOCKER_COUNT=$((BLOCKER_COUNT + 1))
  fi
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
