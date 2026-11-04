#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Install KOReader on a Bookeen Cybook over ADB.
# The device must be in the stock reader (KOReader not running) and have root ADB.

set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ZIP=""
DIR=""
ASSUME_YES=0
DO_REBOOT=0
SKIP_PREFLIGHT=0
ADB_BIN="${ADB:-}"

usage() {
    cat <<'EOF'
Usage: install-via-adb.sh [options]

Options:
  --zip PATH     KOReader bookeen release zip (contains koreader/)
  --dir PATH     Directory containing koreader/koreader.sh
  --adb PATH       adb binary (default: $ADB or adb from PATH)
  --skip-preflight Skip the read-only compatibility checks
  --reboot         Reboot after installation
  --yes            Do not ask for confirmation
  -h, --help       Show this help

The target device must already have ADB enabled:
  create an empty file "adb_debug" in the reader's FAT root, then
  Menu -> Settings -> Enable ADB on the device.
EOF
}

die() { echo "error: $*" >&2; exit 1; }

while [ $# -gt 0 ]; do
    case "$1" in
        --zip) [ $# -ge 2 ] || die "--zip needs a value"; ZIP=$2; shift 2 ;;
        --dir) [ $# -ge 2 ] || die "--dir needs a value"; DIR=$2; shift 2 ;;
        --adb) [ $# -ge 2 ] || die "--adb needs a value"; ADB_BIN=$2; shift 2 ;;
        --skip-preflight) SKIP_PREFLIGHT=1; shift ;;
        --reboot) DO_REBOOT=1; shift ;;
        --yes) ASSUME_YES=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) die "unknown option: $1" ;;
    esac
done

[ -n "$ZIP" ] || [ -n "$DIR" ] || die "provide --zip or --dir"

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

TMP=$(mktemp -d "${TMPDIR:-/tmp}/cybook-install.XXXXXX")
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT INT TERM

if [ -n "$ZIP" ]; then
    [ -f "$ZIP" ] || die "zip not found: $ZIP"
    command -v unzip >/dev/null 2>&1 || die "unzip not found"
    unzip -q "$ZIP" -d "$TMP"
    SRC="$TMP"
else
    [ -d "$DIR" ] || die "directory not found: $DIR"
    if [ -f "$DIR/koreader/koreader.sh" ]; then
        SRC="$DIR"
    elif [ -f "$DIR/koreader.sh" ]; then
        mkdir -p "$TMP/koreader"
        cp -R "$DIR"/. "$TMP/koreader"/
        SRC="$TMP"
    else
        die "no koreader/koreader.sh under $DIR"
    fi
fi

[ -f "$SRC/koreader/koreader.sh" ] || die "payload does not contain koreader/koreader.sh"

echo "==> Checking ADB device"
"$ADB_BIN" get-state >/dev/null 2>&1 || die "no ADB device; enable ADB on the reader"
SERIAL=$("$ADB_BIN" get-serialno | tr -d '\r')
echo "    device: $SERIAL"

ROOT=$("$ADB_BIN" shell id 2>/dev/null | tr -d '\r')
case "$ROOT" in
    *uid=0*) : ;;
    *) die "ADB shell is not root (got: $ROOT)" ;;
esac

if [ -n "$("$ADB_BIN" shell 'pidof luajit 2>/dev/null' | tr -d '\r')" ]; then
    die "KOReader is running. Create koreader/.disabled, reboot to the stock reader, then rerun."
fi

if [ "$SKIP_PREFLIGHT" -ne 1 ]; then
    echo "==> Running read-only preflight"
    ADB="$ADB_BIN" "$REPO_ROOT/scripts/preflight.sh" \
        || die "preflight failed; fix the reported issues or use --skip-preflight"
fi

if [ "$ASSUME_YES" -ne 1 ]; then
    cat <<EOF

This will install KOReader into /mnt/fat/koreader and replace the stock
reader launcher /mnt/app/boordr with a shim. The original reader is kept
at /mnt/app/boordr.stock.

Device: $SERIAL
Continue? [y/N] 
EOF
    read -r answer
    case "$answer" in
        y|Y|yes|YES) : ;;
        *) die "aborted" ;;
    esac
fi

echo "==> Preparing payload"
tar -C "$SRC" -cf "$TMP/koreader.tar" koreader

echo "==> Uploading KOReader"
"$ADB_BIN" push "$TMP/koreader.tar" /mnt/fat/koreader.tar >/dev/null

echo "==> Extracting on device"
"$ADB_BIN" shell 'cd /mnt/fat && rm -rf koreader && tar -xf koreader.tar && rm -f koreader.tar && [ -x koreader/koreader.sh ]' \
    || die "failed to extract koreader/ on device"

echo "==> Installing the Cybook menu plugin"
"$ADB_BIN" shell 'mkdir -p /mnt/fat/koreader/plugins'
"$ADB_BIN" push "$REPO_ROOT/plugin/cybook.koplugin" /mnt/fat/.cybook-plugin.tmp >/dev/null
"$ADB_BIN" shell 'rm -rf /mnt/fat/koreader/plugins/cybook.koplugin && mv /mnt/fat/.cybook-plugin.tmp /mnt/fat/koreader/plugins/cybook.koplugin'

echo "==> Installing boot shim"
"$ADB_BIN" push "$REPO_ROOT/installer/cybook_upgrade" /mnt/fat/cybook_upgrade >/dev/null
"$ADB_BIN" shell 'sh /mnt/fat/cybook_upgrade; rc=$?; rm -f /mnt/fat/cybook_upgrade; echo "--- install log ---"; cat /mnt/fat/koreader-install.log 2>/dev/null; exit $rc' \
    || die "installer failed; see /mnt/fat/koreader-install.log"

if [ "$DO_REBOOT" -eq 1 ]; then
    echo "==> Rebooting"
    "$ADB_BIN" shell '/bin/busybox reboot' >/dev/null 2>&1 || true
else
    echo "==> Done. Reboot the reader to start KOReader."
fi
