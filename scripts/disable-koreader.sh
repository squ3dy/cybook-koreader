#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Make the next boot use the stock Bookeen reader instead of KOReader.

set -eu

DO_REBOOT=0
ADB_BIN="${ADB:-}"

usage() {
    cat <<'EOF'
Usage: disable-koreader.sh [options]

Options:
  --reboot       Reboot after creating the marker
  --adb PATH     adb binary (default: $ADB or adb from PATH)
  -h, --help     Show this help

Creates /mnt/fat/koreader/.disabled. The shim then starts the stock
reader and restarts cyevd on the next boot. Remove the file to return
to KOReader.
EOF
}

die() { echo "error: $*" >&2; exit 1; }

while [ $# -gt 0 ]; do
    case "$1" in
        --reboot) DO_REBOOT=1; shift ;;
        --adb) [ $# -ge 2 ] || die "--adb needs a value"; ADB_BIN=$2; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) die "unknown option: $1" ;;
    esac
done

if [ -z "$ADB_BIN" ]; then
    if command -v adb >/dev/null 2>&1; then
        ADB_BIN=adb
    elif [ -x "$HOME/android-platform-tools/platform-tools/adb" ]; then
        ADB_BIN="$HOME/android-platform-tools/platform-tools/adb"
    elif [ -n "${ANDROID_HOME:-}" ] && [ -x "$ANDROID_HOME/platform-tools/adb" ]; then
        ADB_BIN="$ANDROID_HOME/platform-tools/adb"
    else
        die "adb not found; install Android platform-tools or use --adb"
    fi
fi

"$ADB_BIN" get-state >/dev/null 2>&1 || die "no ADB device; enable ADB on the reader"

ROOT=$("$ADB_BIN" shell id 2>/dev/null | tr -d '\r')
case "$ROOT" in
    *uid=0*) : ;;
    *) die "ADB shell is not root (got: $ROOT)" ;;
esac

"$ADB_BIN" shell 'mkdir -p /mnt/fat/koreader && touch /mnt/fat/koreader/.disabled && sync'

if [ "$DO_REBOOT" -eq 1 ]; then
    "$ADB_BIN" shell '/bin/busybox reboot' >/dev/null 2>&1 || true
    echo "Marker created; rebooting to the stock reader."
else
    echo "Marker created: /mnt/fat/koreader/.disabled"
    echo "Reboot the reader to start the stock reader."
fi
