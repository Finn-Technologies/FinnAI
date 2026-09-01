#!/usr/bin/env bash
# Enforces that only lib/src/engine/backends/ may import llama_cpp_dart.
# Run in CI and as `tool/verify_engine_seam.sh` locally.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BAD=$(grep -rn "import.*package:llama_cpp_dart" "$ROOT/lib/src/engine" --include="*.dart" 2>/dev/null | grep -v "lib/src/engine/backends/" || true)
if [ -n "$BAD" ]; then
  echo "ENGINE SEAM VIOLATION: only lib/src/engine/backends/ may import package:llama_cpp_dart"
  echo "$BAD"
  exit 1
fi
echo "engine seam: OK (no llama_cpp_dart imports outside backends/)"
