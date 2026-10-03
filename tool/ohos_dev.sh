#!/usr/bin/env bash
set -euo pipefail

# Drive the app on a HarmonyOS device/emulator: screenshots, taps, text entry,
# log tails. Wraps hdc/uitest so feature checks are one line each.
#
#   bash tool/ohos_dev.sh shot out.jpeg
#   bash tool/ohos_dev.sh tap 660 1400
#   bash tool/ohos_dev.sh swipe 660 2000 660 800
#   bash tool/ohos_dev.sh text "hello"
#   bash tool/ohos_dev.sh key back
#   bash tool/ohos_dev.sh dump
#   bash tool/ohos_dev.sh logs 200
#   bash tool/ohos_dev.sh logs-finn 200
#   bash tool/ohos_dev.sh clear-logs
#   bash tool/ohos_dev.sh wake

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/tool/ohos_env.sh"

BUNDLE="com.abhiflex.finnai"
SERIAL="${OHOS_SERIAL:-}"

resolve_serial() {
  if [[ -n "$SERIAL" ]]; then
    echo "$SERIAL"
    return
  fi
  local targets count
  targets="$(hdc list targets | grep -v '^\[' | tr -d '\r' | grep -v '^$' || true)"
  count="$(printf '%s\n' "$targets" | grep -c . || true)"
  if [[ "$count" != "1" ]]; then
    echo "Expected one hdc target, found $count. Set OHOS_SERIAL." >&2
    printf '%s\n' "$targets" >&2
    exit 2
  fi
  printf '%s\n' "$targets"
}

SERIAL="$(resolve_serial)"
H=(hdc -t "$SERIAL")

case "${1:-}" in
  shot)
    out="${2:-/tmp/finn.jpeg}"
    "${H[@]}" shell "snapshot_display -f /data/local/tmp/_shot.jpeg" >/dev/null
    "${H[@]}" file recv /data/local/tmp/_shot.jpeg "$out" >/dev/null
    echo "$out"
    ;;
  tap)      "${H[@]}" shell "uitest uiInput click ${2:?x} ${3:?y}" >/dev/null; sleep "${4:-1}" ;;
  doubletap) "${H[@]}" shell "uitest uiInput doubleClick ${2:?x} ${3:?y}" >/dev/null; sleep 1 ;;
  longtap)  "${H[@]}" shell "uitest uiInput longClick ${2:?x} ${3:?y}" >/dev/null; sleep 1 ;;
  swipe)    "${H[@]}" shell "uitest uiInput swipe ${2:?x} ${3:?y} ${4:?x} ${5:?y}" >/dev/null; sleep 1 ;;
  fling)    "${H[@]}" shell "uitest uiInput fling ${2:?x} ${3:?y} ${4:?x} ${5:?y}" >/dev/null; sleep 1 ;;
  text)     "${H[@]}" shell "uitest uiInput text ${2:?text}" >/dev/null; sleep 1 ;;
  key)
    case "${2:-}" in
      back)  "${H[@]}" shell "uitest uiInput keyEvent BACK" >/dev/null ;;
      home)  "${H[@]}" shell "uitest uiInput keyEvent HOME" >/dev/null ;;
      enter) "${H[@]}" shell "uitest uiInput keyEvent ENTER" >/dev/null ;;
      *) echo "Unknown key: $2" >&2; exit 2 ;;
    esac
    sleep 1
    ;;
  dump)
    "${H[@]}" shell "uitest dumpLayout -p /data/local/tmp/_layout.json -b $BUNDLE" >/dev/null
    "${H[@]}" file recv /data/local/tmp/_layout.json - 2>/dev/null \
      || { "${H[@]}" shell "cat /data/local/tmp/_layout.json"; }
    ;;
  logs)      "${H[@]}" shell "hilog -x -T ${1:-200}" ;;
  logs-finn)  "${H[@]}" shell "hilog -x -T ${1:-200} | grep -E 'FINN_|flutter|Dart'" ;;
  clear-logs) "${H[@]}" shell "hilog -r" >/dev/null; echo cleared ;;
  wake)       "${H[@]}" shell "power-shell wakeup" >/dev/null; sleep 1 ;;
  restart)
    "${H[@]}" shell "aa force-stop $BUNDLE" >/dev/null 2>&1 || true
    "${H[@]}" shell "aa start -a EntryAbility -b $BUNDLE"
    ;;
  *)
    sed -n '2,20p' "$0"
    exit 2
    ;;
esac