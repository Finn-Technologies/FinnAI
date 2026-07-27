#!/usr/bin/env bash
set -euo pipefail

echo "======================================================"
echo "   FinnAI Release Readiness Verification Script      "
echo "======================================================"

BLOCKER_COUNT=0

# Files/directories created by this script and removed during cleanup.
# KEY_PROPS_BAK is intentionally NOT added here — it is managed separately
# in the cleanup function so that restoration happens in the right order
# before the backup itself is removed.
CREATED_FILES=()

# ── key.properties lifecycle tracking ────────────────────────────────────────
KEY_PROPS="android/key.properties"

# Path to the unique backup of the original key.properties (set only when a
# pre-existing key.properties was found at startup).
KEY_PROPS_BAK=""

# True when this script wrote a temporary key.properties that did not exist
# before; false when the file already existed (and was merely backed up).
SCRIPT_CREATED_KEY_PROPS=false

# ── cleanup ───────────────────────────────────────────────────────────────────
cleanup() {
  echo "Performing verification cleanup..."

  # 1. Remove the temporary key.properties that this script generated
  #    (only when this script created it; never touch a pre-existing file here).
  if [ "$SCRIPT_CREATED_KEY_PROPS" = "true" ] && [ -f "$KEY_PROPS" ]; then
    rm -f "$KEY_PROPS"
  fi

  # 2. Restore the original key.properties from its unique backup.
  if [ -n "$KEY_PROPS_BAK" ] && [ -f "$KEY_PROPS_BAK" ]; then
    mv "$KEY_PROPS_BAK" "$KEY_PROPS"
    echo "Restored original android/key.properties."
  fi

  # 3. Remove other files/directories created during this run
  #    (temp keystore dir, extracted APK dirs, etc.).
  for file in "${CREATED_FILES[@]}"; do
    if [ -e "$file" ]; then
      rm -rf "$file"
    fi
  done
}
trap cleanup EXIT

# ── Backup pre-existing key.properties with a unique name ────────────────────
if [ -f "$KEY_PROPS" ]; then
  # mktemp guarantees uniqueness — no collision with a pre-existing .bak file.
  KEY_PROPS_BAK=$(mktemp "${KEY_PROPS}.bak.XXXXXX")
  cp "$KEY_PROPS" "$KEY_PROPS_BAK"
  # KEY_PROPS_BAK is removed only AFTER successful restoration (inside cleanup).
  echo "Backed up existing android/key.properties to $KEY_PROPS_BAK"
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

# All four production values are passed as --dart-define flags so the compiled
# binary contains them rather than empty defaults.
DART_DEFINES=(
  "--dart-define=FINN_PRIVACY_POLICY_URL=${FINN_PRIVACY_POLICY_URL}"
  "--dart-define=FINN_TERMS_URL=${FINN_TERMS_URL}"
  "--dart-define=FINN_SUPPORT_EMAIL=${FINN_SUPPORT_EMAIL}"
  "--dart-define=FINN_REPORT_ENDPOINT=${FINN_REPORT_ENDPOINT}"
)

if [ "$PROD_BUILD" = "true" ]; then
  MISSING=()
  [ -z "$FINN_PRIVACY_POLICY_URL" ] && MISSING+=("FINN_PRIVACY_POLICY_URL")
  [ -z "$FINN_TERMS_URL" ]          && MISSING+=("FINN_TERMS_URL")
  [ -z "$FINN_SUPPORT_EMAIL" ]      && MISSING+=("FINN_SUPPORT_EMAIL")
  [ -z "$FINN_REPORT_ENDPOINT" ]    && MISSING+=("FINN_REPORT_ENDPOINT")

  if [ "${#MISSING[@]}" -gt 0 ]; then
    echo "FAIL: Production build missing required configuration variables:"
    for var in "${MISSING[@]}"; do
      echo "  $var: MISSING"
    done
    BLOCKER_COUNT=$((BLOCKER_COUNT + 1))
    exit 1
  fi
fi

# 6. Generate Temporary CI Signing Key and Build Release Artifacts
echo "[6/8] Creating temporary CI signing key and building Release APK & AAB..."

KEYTOOL_BIN="keytool"
if [ -f "/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool" ]; then
  KEYTOOL_BIN="/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool"
fi

# Create a unique temp directory inside android/app/ so the storeFile path
# is correct relative to android/app/. We place the keystore INSIDE this
# directory so mktemp never pre-creates the .jks file — keytool requires the
# keystore path to not already exist (or to be non-empty).
TEMP_JKS_DIR=$(mktemp -d "android/app/verify-ci.XXXXXX")
CREATED_FILES+=("$TEMP_JKS_DIR")
TEMP_JKS="${TEMP_JKS_DIR}/release-ci.jks"
# storeFile in key.properties is a path relative to android/app/.
TEMP_JKS_REL="$(basename "$TEMP_JKS_DIR")/release-ci.jks"

"$KEYTOOL_BIN" -genkey -v -keystore "$TEMP_JKS" \
  -keyalg RSA -keysize 2048 -validity 1 \
  -alias finn_ci_verify -dname "CN=CI, OU=FinnAI, O=FinnAI, L=SF, S=CA, C=US" \
  -storepass verifypass -keypass verifypass >/dev/null 2>&1

# Write a temporary key.properties. Track whether this script created it so
# cleanup knows whether to remove it before restoring the backup.
if [ ! -f "$KEY_PROPS" ]; then
  SCRIPT_CREATED_KEY_PROPS=true
fi

cat <<EOF > "$KEY_PROPS"
storePassword=verifypass
keyPassword=verifypass
keyAlias=finn_ci_verify
storeFile=${TEMP_JKS_REL}
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

# 7. zipalign — missing binary is a hard failure, not a notice
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

# 8. Python ELF parser — ALL .so files in the packaged release APK.
#    Dart-define verification also runs here, against the extracted APK
#    contents, which is the authoritative source of truth for what the
#    compiled binary actually contains.
echo "[8/8] Verifying 16 KB page alignment of ALL packaged native libraries..."

APK_UNZIP_TMP=$(mktemp -d)
CREATED_FILES+=("$APK_UNZIP_TMP")

unzip -oq "$RELEASE_APK" -d "$APK_UNZIP_TMP"

# ── Dart-define embedding verification ───────────────────────────────────────
# Run against the extracted APK tree (classes.dex + compiled assets) so we
# are searching the actual binary content rather than the compressed ZIP.
echo "Verifying dart-define values are embedded in the extracted release APK..."

DEFINE_NAMES=(
  "FINN_PRIVACY_POLICY_URL"
  "FINN_TERMS_URL"
  "FINN_SUPPORT_EMAIL"
  "FINN_REPORT_ENDPOINT"
)
DEFINE_VALUES=(
  "$FINN_PRIVACY_POLICY_URL"
  "$FINN_TERMS_URL"
  "$FINN_SUPPORT_EMAIL"
  "$FINN_REPORT_ENDPOINT"
)

for i in "${!DEFINE_NAMES[@]}"; do
  name="${DEFINE_NAMES[$i]}"
  val="${DEFINE_VALUES[$i]}"
  if [ -n "$val" ]; then
    # Search across all extracted files (dex, assets, libs).
    if grep -rqF "$val" "$APK_UNZIP_TMP" 2>/dev/null; then
      echo "PASSED: $name found embedded in extracted APK contents."
    else
      echo "FAIL: $name NOT found in extracted APK — dart-define was not passed correctly."
      BLOCKER_COUNT=$((BLOCKER_COUNT + 1))
    fi
  else
    echo "SKIP: $name is empty; embedding check skipped."
  fi
done

# ── ELF alignment check ───────────────────────────────────────────────────────
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

        e_phoff     = struct.unpack('<Q', header[32:40])[0]
        e_phentsize = struct.unpack('<H', header[54:56])[0]
        e_phnum     = struct.unpack('<H', header[56:58])[0]

        f.seek(e_phoff)
        min_align  = None
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
