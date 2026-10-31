#!/usr/bin/env bash
# Builds skate1 from your own copy of the game, on Linux (x86-64). Checks what
# it needs first and lists everything missing at once.
#
#   ./build-linux.sh                             asks what it needs
#   ./build-linux.sh --iso "Skate. (USA).iso"    Linux and Steam Deck package
#   ./build-linux.sh --target android            Android APK
#   ./build-linux.sh --emulated                  emulated GPU, not the native renderer
#   ./build-linux.sh --check                     only check, build nothing
#
# Linux and the Steam Deck share one package, built in a container so that it
# runs on both. Android is built from here too: the device compiles nothing.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

TARGET=linux
NATIVE=1
CHECK=0
ASKED=$#
ISO=""
MIN_FREE_GB=40    # sources, game files, generated code and build outputs
MIN_RAM_GB=16     # the recompiled code is compiled in very large files

usage() { sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --iso) [[ $# -ge 2 ]] || usage 1; ISO="$2"; shift ;;
    --target) [[ $# -ge 2 ]] || usage 1; TARGET="$2"; shift ;;
    --native) NATIVE=1 ;;
    --emulated) NATIVE=0 ;;
    --check) CHECK=1 ;;
    -h|--help) usage ;;
    *) echo "unknown option: $1" >&2; usage 1 ;;
  esac
  shift
done
[[ $TARGET == deck ]] && TARGET=linux
[[ $TARGET == linux || $TARGET == android ]] || { echo "unknown target: $TARGET (linux, deck, android)" >&2; exit 1; }

# The ISO's own table of contents tells a game disc from any other file.
is_skate_iso() {
  python3 tools/extract_iso.py "$1" /nonexistent --list 2>/dev/null | grep -qi 'screens\.big'
}

find_iso() {
  local where
  for where in . .. "$HOME/Downloads" "$HOME/Téléchargements" "$HOME/Desktop" "$HOME/Games" /run/media/*/*; do
    [[ -d $where ]] && find "$where" -maxdepth 2 -iname '*.iso' -size +1G 2>/dev/null
  done | sort -u | while IFS= read -r iso; do
    is_skate_iso "$iso" && printf '%s\n' "$iso"
  done
}

# With no option at a terminal: find the disc image and ask for the target.
if [[ $ASKED == 0 && -t 0 ]]; then
  echo "skate1 is built here from your own copy of the game."
  if [[ ! -f game/default.xex ]]; then
    mapfile -t found < <(find_iso)
    if (( ${#found[@]} )); then
      ISO="${found[0]}"
      echo "Found your game: $ISO"
      read -r -p "Press Enter to use it, or type another path: " answer
      [[ -n $answer ]] && ISO="$answer"
    else
      read -r -p "Path to your skate ISO: " ISO
    fi
    ISO="${ISO%\'}"; ISO="${ISO#\'}"; ISO="${ISO/#\~/$HOME}"
  fi
  echo "Build for:  1) Linux and Steam Deck   2) Android"
  read -r -p "Choice [1]: " answer
  [[ $answer == 2 ]] && TARGET=android
fi

# How to install a package here, for the messages below.
install_hint() {
  if command -v apt >/dev/null 2>&1; then echo "sudo apt install $1"
  elif command -v pacman >/dev/null 2>&1; then echo "sudo pacman -S $1"
  elif command -v dnf >/dev/null 2>&1; then echo "sudo dnf install $1"
  elif command -v zypper >/dev/null 2>&1; then echo "sudo zypper install $1"
  else echo "install $1"
  fi
}

missing=0
ok() { printf '  ok       %s\n' "$1"; }
bad() { printf '  MISSING  %s\n' "$1"; missing=$((missing + 1)); }
warn() { printf '  warning  %s\n' "$1"; }
need() {  # need <command> <how to get it>
  if command -v "$1" >/dev/null 2>&1; then ok "$1"; else bad "$1: $2"; fi
}

echo "Checking what the $TARGET build needs:"

[[ $(uname -m) == x86_64 ]] && ok "x86-64 host" || bad "x86-64 host: this is $(uname -m)"
need python3 "$(install_hint python3)"

free_gb=$(df -BG --output=avail . | tail -1 | tr -dc 0-9)
if (( free_gb >= MIN_FREE_GB )); then ok "${free_gb} GB free"; else bad "disk space: ${free_gb} GB free, ${MIN_FREE_GB} GB needed"; fi
ram_gb=$(awk '/MemTotal/ {print int($2 / 1000000)}' /proc/meminfo)
if (( ram_gb >= MIN_RAM_GB )); then ok "${ram_gb} GB of memory"; else warn "${ram_gb} GB of memory, ${MIN_RAM_GB} GB advised: the build may run out"; fi

if [[ -f game/default.xex ]]; then
  ok "game files in game/"
elif [[ -n $ISO && -f $ISO ]]; then
  if is_skate_iso "$ISO"; then ok "game disc: $ISO"; else bad "$ISO is not a skate disc image"; fi
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
    bad "podman or docker: the build runs in a container. $(install_hint podman)"
  fi
fi

if [[ $TARGET == android ]]; then
  ANDROID_NDK="${ANDROID_NDK:-$HOME/Android/android-ndk-r29}"
  ANDROID_SDK="${ANDROID_SDK:-$HOME/Android/sdk}"
  export ANDROID_NDK ANDROID_SDK
  need cmake "$(install_hint cmake)"
  need ninja "$(install_hint ninja)"
  need javac "install a JDK, version 17 or newer"
  need keytool "install a JDK, version 17 or newer"
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

# Each step's whole output goes to build.log, its progress to the terminal.
LOG=build.log
: > "$LOG"
step() {  # step <title> <command...>
  local title="$1"; shift
  echo "$title"
  if [[ -t 1 ]]; then
    "$@" 2>&1 | tee -a "$LOG" | while IFS= read -r line; do
      [[ $line =~ ^\[([0-9]+)/([0-9]+)\] ]] &&
        printf '\r  %s/%s files ' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
    done
    local status=${PIPESTATUS[0]}
    printf '\r\033[K'
  else
    "$@" 2>&1 | tee -a "$LOG"
    local status=${PIPESTATUS[0]}
  fi
  if (( status != 0 )); then
    echo "This step failed. The errors:"
    grep -E ' error|Error |FAILED|error:' "$LOG" | tail -8
    echo "Everything is in $LOG. Run the script again to resume: finished work is kept."
    exit "$status"
  fi
}

if [[ ! -f game/default.xex ]]; then
  step "Extracting your game to game/ (a few minutes)" python3 tools/extract_iso.py "$ISO" game
fi

if [[ $TARGET == linux || ! -f generated/default/sources.cmake ||
      ($NATIVE == 1 && ! -f out/native/shader_cache.cpp) ]]; then
  step "Recompiling the game. The first time takes 15 to 30 minutes." \
    env NATIVE=$NATIVE tools/steamdeck/build.sh
fi
if [[ $TARGET == android ]]; then
  step "Building the Android APK" env NATIVE=$NATIVE tools/android/build.sh
  echo "Done: out/android/package/skate1.apk"
  echo "Install it on the device, then put your game/ folder in a skate1/ folder at the"
  echo "root of its storage. Details: out/android/package/README.txt"
else
  PACKAGE=out/steamdeck/skate1
  [[ $NATIVE == 1 ]] && PACKAGE=out/steamdeck-native/skate1
  echo "Done: $PACKAGE"
  echo "Put your game/ folder in it, or copy the whole folder to the Steam Deck, and run"
  echo "skate1. In game, RB+Start chooses 30, 40 or 60 FPS. Details: $PACKAGE/README.txt"
fi
