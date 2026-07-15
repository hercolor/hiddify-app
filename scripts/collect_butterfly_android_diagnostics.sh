#!/usr/bin/env bash
set -euo pipefail

PACKAGE_NAME="pro.y88.accelerator"
APK_PATH=""
CLEAR_LOGCAT=0
DURATION_SECONDS=0
OUT_FILE=""

usage() {
  cat <<'EOF'
Collect filtered BflyVPN Android routing diagnostics from adb logcat.

Usage:
  scripts/collect_butterfly_android_diagnostics.sh [options]

Options:
  --apk PATH       Install this APK before collecting logs.
  --clear         Clear logcat before collection.
  --duration N    Wait N seconds after --clear, then dump logs.
  --out PATH      Write sanitized filtered logs to PATH.
  -h, --help      Show this help.

Typical flow:
  1. Install the latest APK:
     scripts/collect_butterfly_android_diagnostics.sh --apk out/BflyVPN-android-release-YYYYMMDD-HHMMSS.apk --clear
  2. Open BflyVPN, connect, open hidden diagnostics, run "分流探测".
  3. Collect evidence:
     scripts/collect_butterfly_android_diagnostics.sh --out /tmp/butterfly-diag.log

The script filters for diagnostic evidence only and redacts common token/URL
patterns before writing output.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apk)
      APK_PATH="${2:-}"
      shift 2
      ;;
    --clear)
      CLEAR_LOGCAT=1
      shift
      ;;
    --duration)
      DURATION_SECONDS="${2:-0}"
      shift 2
      ;;
    --out)
      OUT_FILE="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

find_adb() {
  if command -v adb >/dev/null 2>&1; then
    command -v adb
    return
  fi
  for candidate in \
    "${ANDROID_HOME:-}/platform-tools/adb" \
    "${ANDROID_SDK_ROOT:-}/platform-tools/adb" \
    "/home/seven/android-sdk/platform-tools/adb"; do
    if [[ -n "$candidate" && -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return
    fi
  done
  return 1
}

ADB="$(find_adb)" || {
  echo "adb not found. Install Android platform-tools or set ANDROID_HOME/ANDROID_SDK_ROOT." >&2
  exit 1
}

device_count="$("$ADB" devices | awk 'NR > 1 && $2 == "device" { count++ } END { print count + 0 }')"
if [[ "$device_count" -lt 1 ]]; then
  "$ADB" devices >&2 || true
  echo "No authorized Android device attached." >&2
  exit 1
fi
if [[ "$device_count" -gt 1 ]]; then
  "$ADB" devices >&2
  echo "Multiple devices attached. Set ANDROID_SERIAL before running this script." >&2
  exit 1
fi

if [[ -n "$APK_PATH" ]]; then
  if [[ ! -f "$APK_PATH" ]]; then
    echo "APK not found: $APK_PATH" >&2
    exit 1
  fi
  echo "Installing $APK_PATH ..."
  "$ADB" install -r "$APK_PATH"
  "$ADB" shell monkey -p "$PACKAGE_NAME" 1 >/dev/null || true
fi

if [[ "$CLEAR_LOGCAT" -eq 1 ]]; then
  "$ADB" logcat -c
  echo "Cleared logcat."
fi

if [[ "$DURATION_SECONDS" =~ ^[0-9]+$ && "$DURATION_SECONDS" -gt 0 ]]; then
  echo "Waiting ${DURATION_SECONDS}s before dumping logs ..."
  sleep "$DURATION_SECONDS"
fi

FILTER='diagProbe|actualMode|actualExit|policyTrace|final config|routeDefaultDomainResolver|dnsReverseMapping|routeProbe|sniffRule|mixedPort|core log|coreStatus|connectionState|routeFinal|routeRules|dnsServers|rule sets'

sanitize() {
  sed -E \
    -e 's#(https?://)[^[:space:]]+#\1<redacted-url>#g' \
    -e 's#(Bearer )[A-Za-z0-9._~+/=-]+#\1<redacted>#g' \
    -e 's#(token=)[A-Za-z0-9._~+/=-]+#\1<redacted>#g' \
    -e 's#(authData=)[A-Za-z0-9._~+/=-]+#\1<redacted>#g' \
    -e 's#[0-9a-fA-F]{24,}#<redacted-hex>#g'
}

if [[ -n "$OUT_FILE" ]]; then
  mkdir -p "$(dirname "$OUT_FILE")"
  "$ADB" logcat -d -v time | grep -E "$FILTER" | sanitize >"$OUT_FILE" || true
  echo "Wrote filtered diagnostics to $OUT_FILE"
else
  "$ADB" logcat -d -v time | grep -E "$FILTER" | sanitize || true
fi
