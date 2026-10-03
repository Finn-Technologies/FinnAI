#!/usr/bin/env bash
set -euo pipefail

# Build the OpenHarmony debug HAP, install it on a connected HarmonyOS device or
# emulator, and start EntryAbility. Wraps the manual
# `flutter build hap` + `hdc install` + `hdc shell aa start` dance.
#
#   bash tool/run_ohos.sh                 # build + install + launch
#   bash tool/run_ohos.sh --no-build      # reuse the last build
#   bash tool/run_ohos.sh --serial 127.0.0.1:5559
#
# Run tool/patch_ohos_engine_har.sh once first; see docs/guides/OHOS_BUILD.md.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/tool/ohos_env.sh"

BUNDLE="com.abhiflex.finnai"
ABILITY="EntryAbility"
HAP="entry/build/default/outputs/default/entry-default-unsigned.hap"
DO_BUILD=true
SERIAL=""
LOG_LINES="${LOG_LINES:-0}"

usage() {
  cat <<'EOF'
Usage: $0 [--no-build] [--serial HOST:PORT] [--logs N]

  --no-build     skip `flutter build hap` and install the existing HAP
  --serial       hdc target serial (default: the only connected target)
  --logs N       after launch, stream the last N lines of hilog and follow
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-build) DO_BUILD=false; shift ;;
    --serial) SERIAL="$2"; shift 2 ;;
    --logs) LOG_LINES="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

targets="$(hdc list targets | grep -v '^\[' | tr -d '\r' | grep -v '^$' || true)"
if [[ -z "$SERIAL" ]]; then
  count="$(printf '%s\n' "$targets" | grep -c . || true)"
  if [[ "$count" != "1" ]]; then
    echo "Expected exactly one hdc target, found $count:" >&2
    printf '%s\n' "$targets" >&2
    echo "Pass --serial HOST:PORT." >&2
    exit 2
  fi
  SERIAL="$targets"
fi
hdc_target() { hdc -t "$SERIAL" "$@"; }

if [[ ! -z "$SERIAL" ]] && ! hdc_target shell "true" >/dev/null 2>&1; then
  echo "Device $SERIAL is not answering hdc shell yet; waiting..." >&2
  for _ in $(seq 1 30); do
    sleep 5
    if hdc_target shell "true" >/dev/null 2>&1; then break; fi
  done
fi

echo "==> target $SERIAL"
echo "    os: $(hdc_target shell 'param get const.product.software.version' | tr -d '\r')"

if $DO_BUILD; then
  echo "==> flutter build hap --debug"
  (cd "$ROOT" && flutter build hap --debug)
fi

hap_path="$ROOT/ohos/$HAP"
if [[ ! -f "$hap_path" ]]; then
  echo "No HAP at $hap_path" >&2
  exit 1
fi

echo "==> installing $(basename "$hap_path")"
hdc_target uninstall "$BUNDLE" >/dev/null 2>&1 || true
hdc_target install -r "$hap_path"

echo "==> launching $BUNDLE/$ABILITY"
hdc_target shell "aa force-stop $BUNDLE" >/dev/null 2>&1 || true
hdc_target shell "aa start -a $ABILITY -b $BUNDLE"

if [[ "$LOG_LINES" != "0" ]]; then
  echo "==> hilog (last $LOG_LINES lines)"
  hdc_target shell "hilog -x -T $LOG_LINES"
fi