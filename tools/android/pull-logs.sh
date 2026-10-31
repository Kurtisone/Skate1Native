#!/usr/bin/env bash
# Copies the game's logs from an Android device to logsAndroid/, over the
# network. On the device: Developer options > Wireless debugging. Once, pair it:
#   tools/android/pull-logs.sh pair <ip:pairing port> <pairing code>
# Then, with the ip:port shown on the Wireless debugging screen:
#   tools/android/pull-logs.sh <ip:port>
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
ADB="$(command -v adb || echo "${ANDROID_SDK:-$HOME/Android/sdk}/platform-tools/adb")"
if [[ ${1:-} == pair ]]; then
  exec "$ADB" pair "$2" "$3"
fi
[[ -n ${1:-} ]] && "$ADB" connect "$1"
for root in /sdcard/skate1 /sdcard/Android/data/com.kurtisone.skate1/files; do
  if "$ADB" shell "test -d $root/logs"; then
    mkdir -p logsAndroid
    "$ADB" pull "$root/logs/." logsAndroid/ >/dev/null
    for file in crash.txt driver_status.txt; do
      "$ADB" pull "$root/$file" logsAndroid/ >/dev/null 2>&1 || true
    done
    echo "Logs in logsAndroid/: $(ls -t logsAndroid | head -1) is the latest."
    exit 0
  fi
done
echo "No skate1 logs on the device." >&2
exit 1
