#!/usr/bin/env bash
set -euo pipefail

# Builds the llama.cpp runtime FinnAI loads on desktop Linux, from the exact
# source pinned by the vendored llama_cpp_dart package (the same commits the
# Android build uses), and installs it where linux/CMakeLists.txt bundles it
# from: linux/native/<arch>/ (x86_64 or aarch64, the host's architecture).
#
# What it produces (all in one directory, found through the executable's
# $ORIGIN/lib RPATH):
#   libllama.so, libggml.so, libggml-base.so, libmtmd.so
#   libggml-cpu-*.so   one CPU backend per instruction-set level; ggml picks the
#                      best one the machine supports at start-up
#   libggml-vulkan.so  only with --vulkan
#
# Needs: git, cmake (3.14+), ninja or make, a C/C++ compiler. With --vulkan also
# the Vulkan headers and glslc (Fedora: vulkan-headers vulkan-loader-devel
# glslc; Debian/Ubuntu: libvulkan-dev glslc).

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_COMMIT="1a8c7563cb5382e23bcd20dc5720fc8d8099ec58"
LLAMA_COMMIT="d6d0ce8215a1c324e8de04b52f9dd65c5edc129f"
TAG="v0.9.0-dev.9"
REPOSITORY="https://github.com/netdur/llama_cpp_dart.git"
ARCH="$(uname -m)"
OUTPUT="$ROOT/linux/native/$ARCH"
SOURCE=""
VULKAN=false
KEEP_BUILD=false
JOBS="$(nproc 2>/dev/null || echo 4)"

usage() {
  echo "Usage: $0 [--source PATH] [--output DIR] [--vulkan] [--jobs N] [--keep-build]"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source) SOURCE="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --vulkan) VULKAN=true; shift ;;
    --jobs) JOBS="$2"; shift 2 ;;
    --keep-build) KEEP_BUILD=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

for tool in git cmake; do
  if ! command -v "$tool" >/dev/null; then
    echo "$tool is required but was not found in PATH." >&2
    exit 2
  fi
done
if ! command -v c++ >/dev/null && ! command -v g++ >/dev/null \
   && ! command -v clang++ >/dev/null; then
  echo "A C++ compiler is required (Fedora: gcc-c++, Debian/Ubuntu: g++)." >&2
  exit 2
fi
GENERATOR=("-G" "Unix Makefiles")
if command -v ninja >/dev/null; then GENERATOR=("-G" "Ninja"); fi

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
  BUILD_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/finn-llama-linux.XXXXXX")"
  SOURCE="$BUILD_ROOT/llama_cpp_dart"
  git clone --branch "$TAG" --recurse-submodules --depth 1 \
    --shallow-submodules "$REPOSITORY" "$SOURCE"
fi

if [[ "$(git -C "$SOURCE" rev-parse HEAD)" != "$PACKAGE_COMMIT" ]]; then
  echo "Source checkout does not match llama_cpp_dart $TAG ($PACKAGE_COMMIT)." >&2
  exit 1
fi
if [[ "$(git -C "$SOURCE/src/llama.cpp" rev-parse HEAD)" != "$LLAMA_COMMIT" ]]; then
  echo "llama.cpp submodule does not match the pinned commit $LLAMA_COMMIT." >&2
  exit 1
fi

BUILD="${BUILD_ROOT:-$SOURCE/build}/linux-$ARCH"
INSTALL="$BUILD/install"

ARGS=(
  -S "$SOURCE/src/llama.cpp"
  -B "$BUILD"
  "${GENERATOR[@]}"
  -DCMAKE_BUILD_TYPE=Release
  -DCMAKE_INSTALL_PREFIX="$INSTALL"
  -DBUILD_SHARED_LIBS=ON
  # Every library finds its siblings next to itself, and the file names carry
  # no version suffix, so the bundle holds one real file per library.
  -DCMAKE_INSTALL_RPATH='$ORIGIN'
  -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON
  -DCMAKE_PLATFORM_NO_VERSIONED_SONAME=ON
  # Backends are separate libraries chosen at run time: one CPU build per
  # instruction-set level instead of one build tuned to the machine it was
  # compiled on (GGML_NATIVE=OFF), so the same bundle runs on any x86-64 or
  # arm64 machine and still uses AVX2 / AVX-512 / NEON dot-product when present.
  -DGGML_BACKEND_DL=ON
  -DGGML_CPU_ALL_VARIANTS=ON
  -DGGML_NATIVE=OFF
  -DGGML_OPENMP=OFF
  -DGGML_BLAS=OFF
  -DLLAMA_BUILD_TESTS=OFF
  -DLLAMA_BUILD_EXAMPLES=OFF
  -DLLAMA_CURL=OFF
  -DLLAMA_BUILD_SERVER=OFF
  -DLLAMA_BUILD_APP=OFF
  # Tools are what builds libmtmd (their own *-impl.so helpers are not shipped), the image projector the vision features
  # need. MTMD_VIDEO spawns ffmpeg, which FinnAI does not ship.
  -DLLAMA_BUILD_TOOLS=ON
  -DMTMD_VIDEO=OFF
)
if [[ "$VULKAN" == "true" ]]; then
  ARGS+=(-DGGML_VULKAN=ON)
fi

echo "Building $TAG / llama.cpp ${LLAMA_COMMIT:0:8} for linux-$ARCH"
cmake "${ARGS[@]}"
cmake --build "$BUILD" --parallel "$JOBS"
cmake --install "$BUILD"

# GNUInstallDirs puts libraries in lib or lib64 depending on the distribution
# (Fedora: lib64), and the CPU backends can land in either; gather both.
STAGE="$BUILD/stage"
rm -rf "$STAGE"
mkdir -p "$STAGE"
for dir in "$INSTALL/lib" "$INSTALL/lib64" "$BUILD/bin"; do
  [[ -d "$dir" ]] && find "$dir" -maxdepth 1 -name '*.so' ! -name 'libllama-*-impl.so' -exec cp -L {} "$STAGE"/ \;
done
for required in libllama.so libggml.so libggml-base.so libmtmd.so; do
  if [[ ! -e "$STAGE/$required" ]]; then
    echo "Build finished but $required is missing from the install." >&2
    exit 1
  fi
done
if ! ls "$STAGE"/libggml-cpu*.so >/dev/null 2>&1; then
  echo "Build finished but no CPU backend (libggml-cpu*.so) was produced." >&2
  exit 1
fi

mkdir -p "$OUTPUT"
rm -f "$OUTPUT"/*.so "$OUTPUT"/*.so.*
cp "$STAGE"/*.so "$OUTPUT"/
echo "Installed into $OUTPUT:"
ls -1 "$OUTPUT"
echo "Now run: flutter build linux --release"
