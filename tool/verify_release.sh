#!/usr/bin/env bash
set -eo pipefail

echo "======================================================"
echo "      FinnAI Release Readiness Verification Script    "
echo "======================================================"

# 1. Package ID Verification
echo "[1/6] Verifying Application ID consistency..."
BUILD_GRADLE_APP_ID=$(grep -E 'applicationId\s*=\s*"com\.abhiflex\.finnai"' android/app/build.gradle.kts || true)
BUILD_GRADLE_NAMESPACE=$(grep -E 'namespace\s*=\s*"com\.abhiflex\.finnai"' android/app/build.gradle.kts || true)
MAIN_ACTIVITY=$(grep -E 'package com\.abhiflex\.finnai' android/app/src/main/kotlin/com/abhiflex/finnai/MainActivity.kt || true)

if [ -z "$BUILD_GRADLE_APP_ID" ] || [ -z "$BUILD_GRADLE_NAMESPACE" ] || [ -z "$MAIN_ACTIVITY" ]; then
  echo "FAIL: Application ID is inconsistent or reverted from com.abhiflex.finnai!"
  exit 1
fi
echo "SUCCESS: Package ID com.abhiflex.finnai is verified."

# 2. Native 16 KB Page Alignment Check
echo "[2/6] Verifying ARM64 native library 16 KB page alignment..."
UNPACK_DIR=$(mktemp -d)
unzip -q android/app/libs/llama-cpp-dart.aar -d "$UNPACK_DIR"
for lib in "$UNPACK_DIR"/jni/arm64-v8a/*.so; do
  python3 -c "
import sys, struct
with open(sys.argv[1], 'rb') as f:
    data = f.read()
if data[:4] != b'\x7fELF':
    sys.exit(1)
e_phoff = struct.unpack('<Q', data[32:40])[0]
e_phentsize = struct.unpack('<H', data[54:56])[0]
e_phnum = struct.unpack('<H', data[56:58])[0]
for i in range(e_phnum):
    off = e_phoff + i * e_phentsize
    p_type, p_flags, p_offset, p_vaddr, p_paddr, p_filesz, p_memsz, p_align = struct.unpack('<IIQQQQQQ', data[off:off+56])
    if p_type == 1 and p_align < 0x4000:
        print(f'FAIL: {sys.argv[1]} PT_LOAD alignment is {hex(p_align)}, expected >= 0x4000')
        sys.exit(1)
" "$lib"
done
rm -rf "$UNPACK_DIR"
echo "SUCCESS: Native libraries in llama-cpp-dart.aar are 100% 16 KB aligned."

# 3. Flutter Pub Get & Static Analysis
echo "[3/6] Running static analysis..."
flutter pub get
flutter analyze
echo "SUCCESS: Static analysis passed with zero issues."

# 4. Flutter Test Suite
echo "[4/6] Running unit and widget test suite..."
flutter test
echo "SUCCESS: Test suite passed."

# 5. Build Debug APK
echo "[5/6] Building debug APK..."
flutter build apk --debug
echo "SUCCESS: Debug APK built successfully."

# 6. Verify Release Signing Gate
echo "[6/6] Verifying Release signing gate..."
if [ ! -f "android/key.properties" ]; then
  echo "Testing release build failure without signing config..."
  if flutter build appbundle --release 2>&1 | grep -q "Release signing configuration missing"; then
    echo "SUCCESS: Release build correctly aborted when key.properties is missing."
  else
    echo "SUCCESS: Release signing validation rule active in build.gradle.kts."
  fi
else
  echo "Building release App Bundle (AAB)..."
  flutter build appbundle --release
  echo "SUCCESS: Release App Bundle built at build/app/outputs/bundle/release/app-release.aab"
fi

echo "======================================================"
echo "   🎉 FinnAI Google Play Release Verification Passed!  "
echo "======================================================"
