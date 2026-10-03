#!/usr/bin/env bash
set -euo pipefail

# Rebuild FinnAI's OpenHarmony llama.cpp shared libraries from the exact source
# used by the pinned llama_cpp_dart Dart package, and install them into
# ohos/entry/libs/arm64-v8a/. This is the OHOS sibling of
# tool/rebuild_llama_android_aar.sh.
#
# Why this is not optional
# -----------------------
# The .so files have to be compiled against the *HarmonyOS* NDK sysroot, not an
# OpenHarmony one. HarmonyOS ships a musl libc without __register_atfork; a
# llama.cpp built against a newer sysroot references it and then fails to load
# at runtime with
#
#   LlamaLibraryException: failed to open libllama.so: ... Error relocating
#   /data/storage/el1/bundle/libs/arm64/libllama.so: __register_atfork:
#   symbol not found
#
# which the app surfaces as "Not enough free storage to download this model."
# So when the SDK moves, these libs must be rebuilt -- never just re-copied.
#
# Output (shipped inside the HAP at libs/arm64-v8a/):
#   libggml-base.so  libggml.so  libllama.so  libmtmd.so
# with unversioned SONAMEs (tool/llama_ohos_build.patch) so the sandbox can
# dlopen them by bare filename, and a static C++ runtime (OHOS_STL=c++_static)
# so no libc++_shared.so has to be packaged.
#
# Usage:
#   bash tool/rebuild_llama_ohos.sh [--source PATH] [--sdk PATH] [--keep-build]

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_COMMIT="1a8c7563cb5382e23bcd20dc5720fc8d8099ec58"
LLAMA_COMMIT="d6d0ce8215a1c324e8de04b52f9dd65c5edc129f"
TAG="v0.9.0-dev.9"
REPOSITORY="https://github.com/netdur/llama_cpp_dart.git"
OUTPUT="$ROOT/ohos/entry/libs/arm64-v8a"
BUILD_PATCH="$ROOT/tool/llama_ohos_build.patch"
SOURCE=""
SDK="${DEVECO_SDK_HOME:-$HOME/Developer/command-line-tools/sdk}"
KEEP_BUILD=false

usage() {
  echo "Usage: $0 [--source PATH] [--sdk PATH] [--keep-build]"
  echo
  echo "  --sdk PATH  DevEco SDK root (default: \$DEVECO_SDK_HOME or"
  echo "              ~/Developer/command-line-tools/sdk). Needs"
  echo "              <sdk>/default/openharmony/native with build/cmake."
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source) SOURCE="$2"; shift 2 ;;
    --sdk) SDK="$2"; shift 2 ;;
    --keep-build) KEEP_BUILD=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

NATIVE="$SDK/default/openharmony/native"
TOOLCHAIN="$NATIVE/build/cmake/ohos.toolchain.cmake"
if [[ ! -f "$TOOLCHAIN" ]]; then
  echo "HarmonyOS NDK toolchain not found at $TOOLCHAIN" >&2
  echo "Pass --sdk PATH or set DEVECO_SDK_HOME." >&2
  exit 2
fi

for tool in cmake ninja; do
  if ! command -v "$tool" >/dev/null; then
    echo "$tool not found (brew install cmake ninja)." >&2
    exit 2
  fi
done

# The sysroot the libs link against decides whether they load on device, so
# prove up front that it is a HarmonyOS sysroot rather than an OpenHarmony one.
SYSLIB="$NATIVE/sysroot/usr/lib/aarch64-linux-ohos/libc.so"
if [[ -f "$SYSLIB" ]] && command -v nm >/dev/null; then
  if nm -D "$SYSLIB" 2>/dev/null | grep -q "__register_atfork"; then
    echo "Refusing to build: $SYSLIB exports __register_atfork." >&2
    echo "This sysroot is newer than the target OS; libs built against it" >&2
    echo "dlopen with 'symbol not found' on HarmonyOS 6.x." >&2
    exit 1
  fi
  echo "Sysroot OK: no __register_atfork (matches HarmonyOS 6.x libc)."
fi

BUILD_ROOT=""
cleanup() {
  if [[ -n "$BUILD_ROOT" && "$KEEP_BUILD" != "true" ]]; then
    rm -rf "$BUILD_ROOT"
  elif [[ -n "$BUILD_ROOT" ]]; then
    echo "Kept source and build tree at $BUILD_ROOT"
  fi
}
trap cleanup EXIT

if [[ -z "$SOURCE" ]]; then
  BUILD_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/finn-llama-ohos.XXXXXX")"
  SOURCE="$BUILD_ROOT/llama_cpp_dart"
  git clone --branch "$TAG" --recurse-submodules --depth 1 \
    --shallow-submodules "$REPOSITORY" "$SOURCE"
fi

if [[ "$(git -C "$SOURCE" rev-parse HEAD)" != "$PACKAGE_COMMIT" ]]; then
  echo "Source checkout does not match llama_cpp_dart $TAG ($PACKAGE_COMMIT)." >&2
  exit 2
fi
LLAMA_SRC="$SOURCE/src/llama.cpp"
if [[ "$(git -C "$LLAMA_SRC" rev-parse HEAD)" != "$LLAMA_COMMIT" ]]; then
  echo "llama.cpp submodule does not match the pinned commit $LLAMA_COMMIT." >&2
  exit 2
fi

if git -C "$LLAMA_SRC" apply --reverse --check "$BUILD_PATCH" 2>/dev/null; then
  echo "OHOS build-config patch is already applied."
else
  git -C "$LLAMA_SRC" apply --check "$BUILD_PATCH"
  git -C "$LLAMA_SRC" apply "$BUILD_PATCH"
fi

BUILD_DIR="$SOURCE/build/ohos"
INSTALL_DIR="$SOURCE/build/ohos-install"

echo "Building llama.cpp ${LLAMA_COMMIT:0:8} for OHOS arm64-v8a"
echo "  NDK: $NATIVE"
cmake -G Ninja -B "$BUILD_DIR" -S "$LLAMA_SRC" \
  -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
  -DOHOS_ARCH=arm64-v8a \
  -DOHOS_STL=c++_static \
  -DOHOS_PLATFORM_LEVEL=24 \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
  -DBUILD_SHARED_LIBS=ON \
  -DLLAMA_BUILD_EXAMPLES=OFF \
  -DLLAMA_BUILD_TESTS=OFF \
  -DLLAMA_BUILD_SERVER=OFF \
  -DLLAMA_BUILD_APP=OFF \
  -DLLAMA_BUILD_TOOLS=ON \
  -DLLAMA_CURL=OFF \
  -DGGML_OPENMP=OFF \
  -DGGML_LLAMAFILE=OFF \
  -DGGML_NATIVE=OFF \
  -DGGML_BLAS=OFF \
  -DGGML_RPC=OFF \
  -DGGML_BACKEND_DL=OFF \
  -DGGML_CPU_ALL_VARIANTS=OFF \
  -DMTMD_VIDEO=OFF \
  -DCMAKE_C_FLAGS="-O3 -DNDEBUG" \
  -DCMAKE_CXX_FLAGS="-O3 -DNDEBUG"

cmake --build "$BUILD_DIR" --parallel
cmake --install "$BUILD_DIR"

# Ship exactly the libraries the vendored loader and the ELF NEEDED chain
# expect: ggml-base <- ggml-cpu <- ggml <- llama <- mtmd. libggml-cpu.so is a
# separate NEEDED entry (llama.cpp splits the CPU backend out of libggml.so);
# the sandbox resolves it from the same libs/arm64 directory.
RUNTIME_SOS=(libggml-base.so libggml-cpu.so libggml.so libllama.so libmtmd.so)
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/finn-ohos-libs.XXXXXX")"
trap 'rm -rf "$STAGE"; cleanup' EXIT
found_any=false
for so in "${RUNTIME_SOS[@]}"; do
  src="$INSTALL_DIR/lib/$so"
  if [[ ! -f "$src" ]]; then
    src="$(find "$BUILD_DIR" -name "$so" -type f 2>/dev/null | head -1 || true)"
  fi
  if [[ -z "$src" || ! -f "$src" ]]; then
    echo "error: $so was not produced by the build" >&2
    exit 1
  fi
  cp "$src" "$STAGE/$so"
  found_any=true
done
if [[ "$found_any" != "true" ]]; then
  echo "error: no shared libraries found" >&2
  exit 1
fi

# Reject a build whose SONAMEs are versioned: the sandbox dlopen()s by bare
# filename and would never find libllama.so.0.
READELF="$NATIVE/llvm/bin/llvm-readelf"
if [[ -x "$READELF" ]]; then
  for so in "${RUNTIME_SOS[@]}"; do
    soname="$("$READELF" -d "$STAGE/$so" 2>/dev/null \
      | sed -n 's/.*SONAME.*\[\(.*\)\]/\1/p')"
    if [[ "$soname" != "$so" ]]; then
      echo "error: $so has SONAME '$soname', expected '$so'" >&2
      exit 1
    fi
  done
  echo "SONAMEs OK (unversioned)."
fi

mkdir -p "$OUTPUT"
rm -f "$OUTPUT"/*.so
cp "$STAGE"/*.so "$OUTPUT/"
echo "Installed $(ls "$OUTPUT" | tr '\n' ' ')at $OUTPUT"
shasum -a 256 "$OUTPUT"/*.so