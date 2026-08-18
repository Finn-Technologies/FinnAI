#!/usr/bin/env bash
# Export the release upload key's PUBLIC certificate and print its fingerprint.
#
# Google Play's "upload key reset" flow asks you to attach the new upload key's
# certificate (PEM). This script produces it from the same signing configuration
# the Gradle build uses (android/key.properties, falling back to the
# KEYSTORE_* environment variables), without ever printing passwords.
#
# Usage:
#   ./tool/export_upload_key_cert.sh [output.pem]
#
# Default output: build/upload-key-cert.pem
set -euo pipefail

cd "$(dirname "$0")/.."

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

# Locate keytool. Flutter developers usually have it in Android Studio's JBR;
# macOS does not ship a working system keytool by default.
find_keytool() {
  if [ -n "${JAVA_HOME:-}" ] && [ -x "$JAVA_HOME/bin/keytool" ]; then
    echo "$JAVA_HOME/bin/keytool"
    return
  fi
  for studio in \
    "/Applications/Android Studio.app/Contents/jbr/Contents/Home" \
    "/Applications/Android Studio Preview.app/Contents/jbr/Contents/Home"; do
    if [ -x "$studio/bin/keytool" ]; then
      echo "$studio/bin/keytool"
      return
    fi
  done
  if command -v keytool >/dev/null 2>&1; then
    command -v keytool
    return
  fi
  fail "keytool not found. Install a JDK or set JAVA_HOME."
}
KEYTOOL="$(find_keytool)"

# Resolve signing configuration exactly like android/app/build.gradle.kts.
KEYSTORE=""
STORE_PASS=""
KEY_ALIAS=""
KEY_PASS=""
if [ -f android/key.properties ]; then
  while IFS='=' read -r key value; do
    case "$key" in
      storeFile) KEYSTORE="$value" ;;
      storePassword) STORE_PASS="$value" ;;
      keyAlias) KEY_ALIAS="$value" ;;
      keyPassword) KEY_PASS="$value" ;;
    esac
  done < android/key.properties
elif [ -n "${KEYSTORE_PATH:-}" ] && [ -n "${KEYSTORE_PASSWORD:-}" ] \
  && [ -n "${KEY_ALIAS:-}" ] && [ -n "${KEY_PASSWORD:-}" ]; then
  KEYSTORE="$KEYSTORE_PATH"
  STORE_PASS="$KEYSTORE_PASSWORD"
  KEY_ALIAS="$KEY_ALIAS"
  KEY_PASS="$KEY_PASSWORD"
fi
for name in KEYSTORE STORE_PASS KEY_ALIAS KEY_PASS; do
  [ -n "${!name}" ] || fail "$name is not configured. Add android/key.properties or set KEYSTORE_PATH, KEYSTORE_PASSWORD, KEY_ALIAS, KEY_PASSWORD."
done

# storeFile is resolved relative to the android/app module in build.gradle.kts;
# mirror that so a relative path (e.g. release-ci.jks) behaves identically.
case "$KEYSTORE" in
  /*|~*) ;;
  *) KEYSTORE="android/app/$KEYSTORE" ;;
esac
[ -f "$KEYSTORE" ] || fail "Keystore not found: $KEYSTORE"

OUT="${1:-build/upload-key-cert.pem}"
mkdir -p "$(dirname "$OUT")"

"$KEYTOOL" -exportcert -rfc \
  -keystore "$KEYSTORE" \
  -alias "$KEY_ALIAS" \
  -storepass "$STORE_PASS" \
  -keypass "$KEY_PASS" \
  -file "$OUT"

echo "Public certificate exported to: $OUT"
echo
echo "Registered upload key certificate:"
"$KEYTOOL" -printcert -file "$OUT" 2>/dev/null \
  | grep -iE "Owner:|SHA1:|SHA-256:" || true
echo
echo "Verify the SHA1 above matches the upload key registered in Play Console:"
echo "  Setup > App signing > Upload key certificate"
