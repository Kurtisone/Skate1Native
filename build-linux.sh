#!/usr/bin/env bash
# Builds skate1 from your own copy of the game, on Linux (x86-64). Checks what
# it needs first and lists everything missing at once.
#
#   ./build-linux.sh --iso "Skate. (USA).iso"    Linux and Steam Deck package
#   ./build-linux.sh --target android            Android APK
#   ./build-linux.sh --native                    with the native renderer
#   ./build-linux.sh --check                     only check, build nothing
#
# Linux and the Steam Deck share one package, built in a container so that it
# runs on both. Android is built from here too: the device compiles nothing.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

TARGET=linux
NATIVE=0
CHECK=0
ISO=""
MIN_FREE_GB=40    # sources, game files, generated code and build outputs
MIN_RAM_GB=16     # the recompiled code is compiled in very large files

usage() { sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --iso) [[ $# -ge 2 ]] || usage 1; ISO="$2"; shift ;;
    --target) [[ $# -ge 2 ]] || usage 1; TARGET="$2"; shift ;;
    --native) NATIVE=1 ;;
    --check) CHECK=1 ;;
    -h|--help) usage ;;
    *) echo "unknown option: $1" >&2; usage 1 ;;
  esac
  shift
done
[[ $TARGET == deck ]] && TARGET=linux
[[ $TARGET == linux || $TARGET == android ]] || { echo "unknown target: $TARGET (linux, deck, android)" >&2; exit 1; }

missing=0
ok() { printf '  ok       %s\n' "$1"; }
bad() { printf '  MISSING  %s\n' "$1"; missing=$((missing + 1)); }
warn() { printf '  warning  %s\n' "$1"; }
need() {  # need <command> <how to get it>
  if command -v "$1" >/dev/null 2>&1; then ok "$1"; else bad "$1: $2"; fi
}

echo "Checking what the $TARGET build needs:"

[[ $(uname -m) == x86_64 ]] && ok "x86-64 host" || bad "x86-64 host: this is $(uname -m)"
need python3 "install Python 3"

free_gb=$(df -BG --output=avail . | tail -1 | tr -dc 0-9)
if (( free_gb >= MIN_FREE_GB )); then ok "${free_gb} GB free"; else bad "disk space: ${free_gb} GB free, ${MIN_FREE_GB} GB needed"; fi
ram_gb=$(awk '/MemTotal/ {print int($2 / 1000000)}' /proc/meminfo)
if (( ram_gb >= MIN_RAM_GB )); then ok "${ram_gb} GB of memory"; else warn "${ram_gb} GB of memory, ${MIN_RAM_GB} GB advised: the build may run out"; fi

if [[ -f game/default.xex ]]; then
  ok "game files in game/"
elif [[ -n $ISO && -f $ISO ]]; then
  ok "ISO to extract: $ISO"
elif [[ -n $ISO ]]; then
  bad "ISO not found: $ISO"
else
  bad "game files: pass --iso <your skate ISO>, or extract it to game/"
fi

# Linux package, and the code generation Android reuses.
if [[ $TARGET == linux || ! -f generated/default/sources.cmake ||
      ($NATIVE == 1 && ! -f out/native/shader_cache.cpp) ]]; then
  CONTAINER="${CONTAINER:-}"
  if [[ -z $CONTAINER ]]; then
    if command -v podman >/dev/null 2>&1; then CONTAINER=podman
    elif command -v docker >/dev/null 2>&1; then CONTAINER=docker
    fi
  fi
  if [[ -n $CONTAINER ]] && command -v "$CONTAINER" >/dev/null 2>&1; then
    ok "$CONTAINER"
    export CONTAINER
  else
    bad "podman or docker: install one, the build runs in a container"
  fi
fi

if [[ $TARGET == android ]]; then
  ANDROID_NDK="${ANDROID_NDK:-$HOME/Android/android-ndk-r29}"
  ANDROID_SDK="${ANDROID_SDK:-$HOME/Android/sdk}"
  export ANDROID_NDK ANDROID_SDK
  need cmake "install CMake 3.25 or newer"
  need ninja "install Ninja"
  need javac "install a JDK"
  need keytool "install a JDK"
  [[ -f $ANDROID_NDK/build/cmake/android.toolchain.cmake ]] && ok "Android NDK" ||
    bad "Android NDK r29: unpack it and set ANDROID_NDK (looked in $ANDROID_NDK)"
  [[ -f $ANDROID_SDK/platforms/android-35/android.jar ]] && ok "Android SDK platform 35" ||
    bad "Android SDK platform 35: sdkmanager 'platforms;android-35', set ANDROID_SDK (looked in $ANDROID_SDK)"
  [[ -x $ANDROID_SDK/build-tools/35.0.0/aapt2 ]] && ok "Android build-tools 35.0.0" ||
    bad "Android build-tools 35.0.0: sdkmanager 'build-tools;35.0.0'"
fi

if (( missing > 0 )); then
  echo "$missing missing, nothing was built."
  exit 1
fi
echo "All good."
[[ $CHECK == 1 ]] && exit 0

set -e
if [[ ! -f game/default.xex ]]; then
  echo "Extracting the ISO to game/"
  python3 tools/extract_iso.py "$ISO" game
fi

if [[ $TARGET == linux || ! -f generated/default/sources.cmake ||
      ($NATIVE == 1 && ! -f out/native/shader_cache.cpp) ]]; then
  echo "Building the Linux package. The first build takes a long time: it recompiles the whole game."
  NATIVE=$NATIVE tools/steamdeck/build.sh
fi
if [[ $TARGET == android ]]; then
  NATIVE=$NATIVE tools/android/build.sh
  echo "Done: out/android/package (see its README.txt)"
elif [[ $NATIVE == 1 ]]; then
  echo "Done: out/steamdeck-native/skate1 (see its README.txt)"
else
  echo "Done: out/steamdeck/skate1 (see its README.txt)"
fi
