#!/usr/bin/env bash
# Architecture guardrails for a codebase many agents edit. Three rules, each
# with a *baseline* of pre-existing violations in tool/boundaries_baseline.txt.
# The baseline may only shrink: a new violation fails, and so does growth of a
# baselined one. Fixing a violation and deleting its line is always welcome.
#
#   1. layering  engine/ imports nothing from features/, app/, shared/ or platform/
#   2. features  a feature imports another feature only if it is the composition
#                root (chat) or the edge is baselined
#   3. size      a Dart file stays <= MAX_LINES lines (generated l10n excluded)
#
# Usage: bash tool/verify_boundaries.sh [--print-baseline]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
BASELINE="tool/boundaries_baseline.txt"
MAX_LINES=600
COMPOSITION_ROOT="chat"

current() {
  # layering
  grep -rn "import 'package:finn_ai/src/\(features\|app\|shared\|platform\)/" lib/src/engine --include='*.dart' 2>/dev/null |
    sed -E "s#^([^:]+):[0-9]+:.*package:finn_ai/src/([a-z_]+/[a-z_]+)/.*#layer \1 -> \2#" || true
  # features
  grep -rn "import 'package:finn_ai/src/features/" lib/src/features --include='*.dart' 2>/dev/null |
    sed -E "s#^lib/src/features/([a-z_]+)/[^:]*:[0-9]+:.*src/features/([a-z_]+)/.*#feature \1 -> \2#" |
    awk -v root="$COMPOSITION_ROOT" '$2!=$4 && $2!=root' || true
  # size
  find lib -name '*.dart' ! -name 'app_localizations*' -print0 |
    xargs -0 wc -l | awk -v max="$MAX_LINES" '$2!="total" && $1>max {print "size " $2 " " $1}'
}

if [ "${1:-}" = "--print-baseline" ]; then
  current | sort -u
  exit 0
fi

fail=0
declare -a NOTES=()
CUR="$(current | sort -u)"

while IFS= read -r line; do
  [ -z "$line" ] && continue
  kind="${line%% *}"
  if [ "$kind" = "size" ]; then
    file="$(echo "$line" | awk '{print $2}')"
    lines="$(echo "$line" | awk '{print $3}')"
    allowed="$(awk -v f="$file" '$1=="size" && $2==f {print $3}' "$BASELINE")"
    if [ -z "$allowed" ]; then
      echo "SIZE: $file is $lines lines (max $MAX_LINES). Split it; do not add it to the baseline."
      fail=1
    elif [ "$lines" -gt "$allowed" ]; then
      echo "SIZE: $file grew from $allowed to $lines lines. Baselined files may only shrink."
      fail=1
    elif [ "$lines" -lt "$allowed" ]; then
      NOTES+=("size: $file is down to $lines (baseline $allowed) - tighten tool/boundaries_baseline.txt")
    fi
  else
    if ! grep -qxF "$line" "$BASELINE"; then
      case "$kind" in
        layer) echo "LAYERING: ${line#layer }  (engine/ must not depend on app code)";;
        feature) echo "FEATURE EDGE: ${line#feature }  (only '$COMPOSITION_ROOT' may import other features; depend on an interface instead)";;
      esac
      fail=1
    fi
  fi
done <<< "$CUR"

# Baselined entries that no longer occur: tell the author to delete them.
while IFS= read -r line; do
  [ -z "$line" ] && continue
  case "$line" in \#*) continue;; esac
  kind="${line%% *}"
  [ "$kind" = "size" ] && continue
  grep -qxF "$line" <<< "$CUR" || NOTES+=("fixed: '$line' - delete it from the baseline")
done < "$BASELINE"

for n in "${NOTES[@]:-}"; do [ -n "$n" ] && echo "note: $n"; done
if [ "$fail" -ne 0 ]; then
  echo "boundaries: FAILED"
  exit 1
fi
echo "boundaries: OK"
