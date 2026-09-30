#!/usr/bin/env bash
#
# Runs the on-device evaluation suite and, optionally, writes a committed
# baseline. This is the `tool/eval --baseline` entry point from PLAN.md
# Phase 0: one command produces the numbers that go into `eval/`.
#
#   ./tool/run_eval.sh                       # gate against the committed baseline
#   ./tool/run_eval.sh --write-baseline      # measure and overwrite the baseline
#   ./tool/run_eval.sh --suites factual,math # narrow the run
#   ./tool/run_eval.sh --max-cases 8         # quick smoke pass
#   ./tool/run_eval.sh --prompts file.json   # add non-Latin cases from a file
#
# The app must already have the model installed (Settings -> AI Models). A run
# that starts before the model is resident reports the cold load in the first
# turn; `--write-baseline` warms first so that number is not baked in.
#
# The phone must stay unlocked and in the foreground: Android puts a
# never-visible process in the background cgroup, where MIUI throttles the big
# CPU cluster to ~700MHz and decode collapses ~45x.

set -euo pipefail

cd "$(dirname "$0")/.."

PACKAGE="com.abhiflex.finnai"
ACTIVITY="${PACKAGE}/.MainActivity"
REMOTE_DIR="/sdcard/Android/data/${PACKAGE}/files"
BASELINE_SLUG="${BASELINE_SLUG:-$(git config user.name 2>/dev/null | tr -d ' ')-device}"

SUITES=""
MAX_CASES=0
PROMPT_FILE=""
WRITE_BASELINE=0
SKIP_BUILD=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --write-baseline) WRITE_BASELINE=1; shift ;;
    --suites) SUITES="$2"; shift 2 ;;
    --max-cases) MAX_CASES="$2"; shift 2 ;;
    --prompts) PROMPT_FILE="$2"; shift 2 ;;
    --skip-build) SKIP_BUILD=1; shift ;;
    -h|--help) sed -n '2,25p' "$0"; exit 0 ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
done

command -v adb >/dev/null || { echo "adb not found" >&2; exit 1; }
adb get-state >/dev/null 2>&1 || {
  echo "no device attached (adb devices)" >&2; exit 1;
}

DEFINES=(--dart-define=FINN_EVALUATION=true)
[[ -n "$SUITES" ]] && DEFINES+=(--dart-define=FINN_EVAL_SUITES="$SUITES")
[[ "$MAX_CASES" -gt 0 ]] && DEFINES+=(--dart-define=FINN_EVAL_MAX_CASES="$MAX_CASES")

if [[ "$WRITE_BASELINE" -eq 1 ]]; then
  BASELINE_NAME="baseline_${BASELINE_SLUG}.json"
  DEFINES+=(--dart-define=FINN_EVAL_WRITE_BASELINE="${BASELINE_NAME}")
else
  BASELINE_NAME="baseline_${BASELINE_SLUG}.json"
  if [[ ! -f "eval/${BASELINE_NAME}" ]]; then
    echo "no committed baseline at eval/${BASELINE_NAME}." >&2
    echo "measure one first:  ./tool/run_eval.sh --write-baseline" >&2
    exit 1
  fi
  adb push "eval/${BASELINE_NAME}" "${REMOTE_DIR}/${BASELINE_NAME}" >/dev/null
  DEFINES+=(--dart-define=FINN_EVAL_BASELINE="${REMOTE_DIR}/${BASELINE_NAME}")
fi

if [[ -n "$PROMPT_FILE" ]]; then
  # Non-Latin prompts cannot survive `adb shell input text`, so they travel
  # as a file the app reads instead.
  adb push "$PROMPT_FILE" "${REMOTE_DIR}/$(basename "$PROMPT_FILE")" >/dev/null
  DEFINES+=(--dart-define=FINN_EVAL_PROMPT_FILE="${REMOTE_DIR}/$(basename "$PROMPT_FILE")")
fi

if [[ "$SKIP_BUILD" -eq 0 ]]; then
  echo "building the evaluation APK..."
  flutter build apk --debug --no-pub "${DEFINES[@]}"
  adb install -r -t build/app/outputs/flutter-apk/app-debug.apk
fi

adb logcat -c || true
adb shell am force-stop "$PACKAGE"
adb shell am start -n "$ACTIVITY" >/dev/null

echo "running the suite on the device; this takes minutes and warms the phone"
echo "keep the screen on and the cable in. Ctrl-C to stop and still keep the partial log."

LOG="$(mktemp -t finn-eval)"
# The suite runs 15-20 minutes against a 1.6B model, which is long enough for
# a flaky USB link to drop mid-run. `adb logcat` exits when the device does, and
# without this the whole baseline is lost to a cable; re-establish the transport
# and keep draining until the app reports its summary or we give up.
WATCH_SECONDS="${WATCH_SECONDS:-2700}"
set +e
( while true; do
    adb logcat -s flutter 2>/dev/null
    sleep 3
    adb get-state >/dev/null 2>&1 || { sleep 5; continue; }
  done ) | tee "$LOG" | grep --line-buffered -E "FINN_EVAL|FINN_TTFT_SUMMARY" &
READER=$!

for _ in $(seq 1 "$((WATCH_SECONDS / 5))"); do
  # The app writes the baseline *after* it logs the summary, so a baseline run
  # waits for the write to be reported rather than racing it.
  if [[ "$WRITE_BASELINE" -eq 1 ]]; then
    if grep -qE "FINN_EVAL_BASELINE_(WRITTEN|FAILED)" "$LOG" 2>/dev/null; then break; fi
  elif grep -q "FINN_EVAL_SUMMARY" "$LOG" 2>/dev/null; then break; fi
  if ! kill -0 "$READER" 2>/dev/null; then break; fi
  sleep 5
done
kill "$READER" 2>/dev/null
pkill -f "adb logcat -s flutter" 2>/dev/null
wait "$READER" 2>/dev/null
set -e

echo
echo "--- summary ---"
grep -m1 "FINN_EVAL_SUMMARY" "$LOG" || echo "no summary: the run did not finish"
echo "--- gates ---"
grep -m1 "FINN_EVAL_GATE" "$LOG" || true
echo "full log: $LOG"

if [[ "$WRITE_BASELINE" -eq 1 ]]; then
  # The app writes into its own files directory (external storage is not
  # writable); a debug build lets `run-as` read it back out.
  if adb exec-out run-as "$PACKAGE" cat "files/${BASELINE_NAME}" > "eval/${BASELINE_NAME}.tmp" 2>/dev/null \
      && [[ -s "eval/${BASELINE_NAME}.tmp" ]]; then
    mv "eval/${BASELINE_NAME}.tmp" "eval/${BASELINE_NAME}"
    echo "wrote eval/${BASELINE_NAME} — review it, then commit it"
  else
    rm -f "eval/${BASELINE_NAME}.tmp"
    echo "the app did not write ${BASELINE_NAME}; the run probably did not finish"
  fi
fi
