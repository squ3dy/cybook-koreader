#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Restore the stock Bookeen reader and remove the KOReader boot shim.

set -eu

ASSUME_YES=0
DO_REBOOT=0
PURGE=0
ADB_BIN="${ADB:-}"

usage() {
    cat <<'EOF'
Usage: uninstall-via-adb.sh [options]

Options:
  --purge        Also delete /mnt/fat/koreader and the install log
  --reboot       Reboot after restoring the stock reader
  --adb PATH     adb binary (default: $ADB or adb from PATH)
  --yes          Do not ask for confirmation
  -h, --help     Show this help

The device must be in the stock reader (KOReader not running).
EOF
}

die() { echo "error: $*" >&2; exit 1; }

while [ $# -gt 0 ]; do
    case "$1" in
        --purge) PURGE=1; shift ;;
        --reboot) DO_REBOOT=1; shift ;;
        --adb) [ $# -ge 2 ] || die "--adb needs a value"; ADB_BIN=$2; shift 2 ;;
        --yes) ASSUME_YES=1; shift ;;
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
SERIAL=$("$ADB_BIN" get-serialno | tr -d '\r')
echo "==> Device: $SERIAL"

ROOT=$("$ADB_BIN" shell id 2>/dev/null | tr -d '\r')
case "$ROOT" in
    *uid=0*) : ;;
    *) die "ADB shell is not root (got: $ROOT)" ;;
esac

if [ -n "$("$ADB_BIN" shell 'pidof luajit 2>/dev/null' | tr -d '\r')" ]; then
    die "KOReader is running. Create koreader/.disabled, reboot to the stock reader, then rerun."
fi

if [ "$ASSUME_YES" -ne 1 ]; then
    cat <<EOF

This restores /mnt/app/boordr from /mnt/app/boordr.stock and removes
the KOReader shim. The koreader folder is kept unless --purge is used.

Device: $SERIAL
Continue? [y/N] 
EOF
    read -r answer
    case "$answer" in
        y|Y|yes|YES) : ;;
        *) die "aborted" ;;
    esac
fi

echo "==> Restoring stock reader"
"$ADB_BIN" shell '
set -e
mount -o remount,rw /
if [ ! -e /mnt/app/boordr.stock ]; then
    echo "ERROR: /mnt/app/boordr.stock is missing; refusing to touch the reader." >&2
    mount -o remount,ro /
    exit 1
fi
mv -f /mnt/app/boordr.stock /mnt/app/boordr
sync
mount -o remount,ro /
echo "stock reader restored"
' || die "restore failed"

if [ "$PURGE" -eq 1 ]; then
    echo "==> Removing KOReader files"
    "$ADB_BIN" shell 'rm -rf /mnt/fat/koreader /mnt/fat/koreader-install.log'
fi

if [ "$DO_REBOOT" -eq 1 ]; then
    echo "==> Rebooting"
    "$ADB_BIN" shell '/bin/busybox reboot' >/dev/null 2>&1 || true
else
    echo "==> Done. Reboot to start the stock reader."
fi
