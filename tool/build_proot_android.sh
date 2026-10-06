#!/usr/bin/env bash
# Builds the proot binaries FinnAI Code's Linux sandbox runs (ADR 0012) for
# Android arm64, from pinned sources, and installs them as jniLibs:
#
#   android/app/src/main/jniLibs/arm64-v8a/libproot.so         (proot)
#   android/app/src/main/jniLibs/arm64-v8a/libproot-loader.so  (its loader)
#
# They are named lib*.so only so Android extracts them to nativeLibraryDir,
# the one place an app may execute files from (targetSdk >= 29). Both are
# GPL-2.0 (proot) with talloc (LGPL-3.0) linked statically; the sources are the
# pinned archives below. 16 KB page aligned (the release gate checks it).
#
# Usage: tool/build_proot_android.sh  (needs the Android NDK, r28 or later)
set -euo pipefail

PROOT_COMMIT=a179d3e8a4e045aaa1fb8cc3284f23509d96d353 # termux/proot, 2026-10-01
TALLOC_VERSION=2.4.2
TALLOC_SHA256=85ecf9e465e20f98f9950a52e9a411e14320bc555fa257d87697b7e7a9b1d8a6
API=26

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NDK="${ANDROID_NDK_HOME:-$({ ls -d "$HOME"/Library/Android/sdk/ndk/* "$HOME"/Android/Sdk/ndk/* 2>/dev/null || true; } | sort -V | tail -1)}"
HOST_TAG="$(ls "$NDK/toolchains/llvm/prebuilt" | head -1)"
T="$NDK/toolchains/llvm/prebuilt/$HOST_TAG/bin"
CC="$T/aarch64-linux-android$API-clang"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"

curl -fsSL -o talloc.tar.gz "https://www.samba.org/ftp/talloc/talloc-$TALLOC_VERSION.tar.gz"
echo "$TALLOC_SHA256  talloc.tar.gz" | shasum -a 256 -c -
curl -fsSL -o proot.tar.gz "https://github.com/termux/proot/archive/$PROOT_COMMIT.tar.gz"
tar xzf talloc.tar.gz
tar xzf proot.tar.gz
mv "proot-$PROOT_COMMIT" proot

# talloc alone, without samba's waf build: a stand-in for lib/replace.
mkdir shim
cat > shim/replace.h <<'EOF'
#ifndef _FINN_REPLACE_H
#define _FINN_REPLACE_H
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <sys/types.h>
#include <stddef.h>
#ifndef MIN
#define MIN(a,b) ((a)<(b)?(a):(b))
#endif
#ifndef MAX
#define MAX(a,b) ((a)>(b)?(a):(b))
#endif
#define likely(x) __builtin_expect(!!(x), 1)
#define unlikely(x) __builtin_expect(!!(x), 0)
#define discard_const(ptr) ((void *)((uintptr_t)(ptr)))
#define discard_const_p(type, ptr) ((type *)discard_const(ptr))
#define HAVE_VA_COPY 1
#define HAVE_INTPTR_T 1
#define HAVE_CONSTRUCTOR_ATTRIBUTE 1
#define HAVE_DESTRUCTOR_ATTRIBUTE 1
#define TALLOC_BUILD_VERSION_MAJOR 2
#define TALLOC_BUILD_VERSION_MINOR 4
#define TALLOC_BUILD_VERSION_RELEASE 2
#define _PUBLIC_ __attribute__((visibility("default")))
#define _PRIVATE_
#define PRINTF_ATTRIBUTE(a1, a2) __attribute__ ((format (__printf__, a1, a2)))
#endif
EOF
"$CC" -O2 -fPIC -Ishim -I"talloc-$TALLOC_VERSION" -c "talloc-$TALLOC_VERSION/talloc.c" -o talloc.o
"$T/llvm-ar" rcs libtalloc.a talloc.o

# One missing include upstream at this commit.
sed -i.bak '1s/^/#include <string.h>\n/' proot/src/extension/ashmem_memfd/ashmem_memfd.c

make -C proot/src \
  CC="$CC" STRIP="$T/llvm-strip" OBJCOPY="$T/llvm-objcopy" OBJDUMP="$T/llvm-objdump" \
  PROOT_UNBUNDLE_LOADER=/unused \
  CFLAGS="-I$WORK/talloc-$TALLOC_VERSION -Os -Wno-implicit-function-declaration -DPROOT_UNBUNDLE_LOADER=\\\"/unused\\\"" \
  LDFLAGS="$WORK/libtalloc.a -Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384 -Wl,-z,noexecstack" \
  proot loader/loader

OUT="$ROOT/android/app/src/main/jniLibs/arm64-v8a"
mkdir -p "$OUT"
"$T/llvm-strip" -o "$OUT/libproot.so" proot/src/proot
"$T/llvm-strip" -o "$OUT/libproot-loader.so" proot/src/loader/loader
"$T/llvm-readelf" -lW "$OUT/libproot.so" "$OUT/libproot-loader.so" | grep LOAD
shasum -a 256 "$OUT/libproot.so" "$OUT/libproot-loader.so"
