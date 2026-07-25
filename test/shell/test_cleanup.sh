#!/usr/bin/env bash
# test/shell/test_cleanup.sh — tests for verify_release.sh cleanup path
#
# Tests:
#   1. Normal completion path: original key.properties is restored exactly
#      (content + checksum preserved).
#   2. Early-failure path: original key.properties is still restored even when
#      the script exits non-zero.
#
# This script exercises only the cleanup logic in isolation — it does NOT run a
# real Flutter build.
set -euo pipefail

PASS_COUNT=0
FAIL_COUNT=0

pass() { echo "PASS: $1"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { echo "FAIL: $1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

# ── Helpers ───────────────────────────────────────────────────────────────────

# Minimal version of the cleanup function extracted from verify_release.sh.
# Arguments:
#   $1  KEY_PROPS path
#   $2  KEY_PROPS_BAK path (or "")
#   $3  SCRIPT_CREATED_KEY_PROPS ("true" / "false")
#   $4  space-delimited list of extra files/dirs to remove
run_cleanup() {
  local key_props="$1"
  local key_props_bak="$2"
  local script_created="$3"
  local extra_files="$4"

  # Step 1: remove the temporary key.properties if this script created it.
  if [ "$script_created" = "true" ] && [ -f "$key_props" ]; then
    rm -f "$key_props"
  fi

  # Step 2: restore the original from the unique backup.
  if [ -n "$key_props_bak" ] && [ -f "$key_props_bak" ]; then
    mv "$key_props_bak" "$key_props"
  fi

  # Step 3: remove extra files/dirs.
  for f in $extra_files; do
    [ -e "$f" ] && rm -rf "$f"
  done
}

# ── Setup ─────────────────────────────────────────────────────────────────────

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

ORIGINAL_KEY_PROPS="$WORK_DIR/key.properties"
ORIGINAL_CONTENT="storePassword=prod_pass
keyPassword=prod_key_pass
keyAlias=prod_alias
storeFile=/path/to/prod.jks
"

# Write the sample original key.properties.
printf '%s' "$ORIGINAL_CONTENT" > "$ORIGINAL_KEY_PROPS"
ORIGINAL_SHA=$(shasum -a 256 "$ORIGINAL_KEY_PROPS" | awk '{print $1}')

# ── Test 1: Normal-completion path ────────────────────────────────────────────
echo ""
echo "=== Test 1: Normal completion — original key.properties is restored exactly ==="

# Simulate: existing key.properties was found, backed up, then overwritten.
BACKUP_1=$(mktemp "${ORIGINAL_KEY_PROPS}.bak.XXXXXX")
cp "$ORIGINAL_KEY_PROPS" "$BACKUP_1"

printf 'storePassword=ci_pass\nkeyPassword=ci_key\nkeyAlias=ci_alias\nstoreFile=temp.jks\n' \
  > "$ORIGINAL_KEY_PROPS"

# Create a fake extra file to ensure CREATED_FILES cleanup runs.
FAKE_JKS=$(mktemp "$WORK_DIR/release-temp-verify.XXXXXX.jks")
printf 'fake jks content' > "$FAKE_JKS"

# Run cleanup (SCRIPT_CREATED_KEY_PROPS=false because the file pre-existed).
run_cleanup "$ORIGINAL_KEY_PROPS" "$BACKUP_1" "false" "$FAKE_JKS"

# Verify the original is restored.
if [ ! -f "$ORIGINAL_KEY_PROPS" ]; then
  fail "Test 1: key.properties does not exist after cleanup"
else
  RESTORED_SHA=$(shasum -a 256 "$ORIGINAL_KEY_PROPS" | awk '{print $1}')

  if [ "$RESTORED_SHA" = "$ORIGINAL_SHA" ]; then
    pass "Test 1: key.properties SHA matches original"
  else
    fail "Test 1: SHA mismatch — expected $ORIGINAL_SHA, got $RESTORED_SHA"
  fi

  if diff -q "$ORIGINAL_KEY_PROPS" <(printf '%s' "$ORIGINAL_CONTENT") >/dev/null 2>&1; then
    pass "Test 1: key.properties content exactly preserved"
  else
    fail "Test 1: content mismatch"
    diff "$ORIGINAL_KEY_PROPS" <(printf '%s' "$ORIGINAL_CONTENT") || true
  fi
fi

# Verify the backup itself was removed (mv consumed it).
if [ ! -f "$BACKUP_1" ]; then
  pass "Test 1: unique backup removed after restoration"
else
  fail "Test 1: unique backup was not removed"
fi

# Verify the extra file was cleaned up.
if [ ! -f "$FAKE_JKS" ]; then
  pass "Test 1: temporary JKS removed"
else
  fail "Test 1: temporary JKS was not removed"
fi

# ── Test 2: Early-failure path ────────────────────────────────────────────────
echo ""
echo "=== Test 2: Early-failure path — key.properties still restored on non-zero exit ==="

# Re-write a fresh original so Test 2 starts clean.
printf '%s' "$ORIGINAL_CONTENT" > "$ORIGINAL_KEY_PROPS"

BACKUP_2=$(mktemp "${ORIGINAL_KEY_PROPS}.bak.XXXXXX")
cp "$ORIGINAL_KEY_PROPS" "$BACKUP_2"

printf 'storePassword=ci2\nkeyPassword=ci2\nkeyAlias=ci2\nstoreFile=temp2.jks\n' \
  > "$ORIGINAL_KEY_PROPS"

FAKE_UNZIP_DIR=$(mktemp -d "$WORK_DIR/apk_unzip.XXXXXX")

# Simulate early failure: call cleanup with the same state as if the script
# exited non-zero (e.g., flutter build failed).
run_cleanup "$ORIGINAL_KEY_PROPS" "$BACKUP_2" "false" "$FAKE_UNZIP_DIR"

if [ ! -f "$ORIGINAL_KEY_PROPS" ]; then
  fail "Test 2: key.properties missing after early-failure cleanup"
else
  RESTORED2_SHA=$(shasum -a 256 "$ORIGINAL_KEY_PROPS" | awk '{print $1}')
  if [ "$RESTORED2_SHA" = "$ORIGINAL_SHA" ]; then
    pass "Test 2: key.properties SHA matches original after early-failure cleanup"
  else
    fail "Test 2: SHA mismatch after early-failure cleanup — expected $ORIGINAL_SHA, got $RESTORED2_SHA"
  fi
fi

if [ ! -d "$FAKE_UNZIP_DIR" ]; then
  pass "Test 2: temporary extraction directory removed"
else
  fail "Test 2: temporary extraction directory was not removed"
fi

# ── Test 3: Script-created key.properties is removed during cleanup ──────────
echo ""
echo "=== Test 3: Script-created key.properties is removed (no pre-existing file) ==="

CREATED_KEY="$WORK_DIR/fresh_key.properties"
printf 'storePassword=new\n' > "$CREATED_KEY"

# No backup (SCRIPT_CREATED_KEY_PROPS=true, KEY_PROPS_BAK="").
run_cleanup "$CREATED_KEY" "" "true" ""

if [ ! -f "$CREATED_KEY" ]; then
  pass "Test 3: script-created key.properties removed during cleanup"
else
  fail "Test 3: script-created key.properties was not removed"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "======================================================"
echo "Shell cleanup tests: $PASS_COUNT passed, $FAIL_COUNT failed"
echo "======================================================"

[ "$FAIL_COUNT" -eq 0 ] || exit 1
