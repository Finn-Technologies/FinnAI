#!/usr/bin/env bash
# Enforces the engine seam rule: only lib/src/engine/** may import
# package:llama_cpp_dart (directly or via backends/llama_shim.dart).
# Scans ALL of lib/ — not just lib/src/engine/ — so the rule holds for
# app code too (main.dart, UI, services). Run in CI and locally.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BAD=$(grep -rn "import.*package:llama_cpp_dart" "$ROOT/lib" --include="*.dart" 2>/dev/null | grep -v "/lib/src/engine/" || true)
if [ -n "$BAD" ]; then
  echo "ENGINE SEAM VIOLATION: only lib/src/engine/** may import package:llama_cpp_dart"
  echo "$BAD"
  exit 1
fi
echo "engine seam: OK (no llama_cpp_dart imports outside lib/src/engine/)"
