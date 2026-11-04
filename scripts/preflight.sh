#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Read-only compatibility check. Run it before installing or updating.
# It writes nothing to the device.
#
# Usage:
#   ./scripts/preflight.sh
#   ADB=/path/to/adb ./scripts/preflight.sh
#
# Tested values are for CYBOY5F, firmware build 11. A failed required check
# means: stop, do not install.

set -u

ADB="${ADB:-adb}"
STOCK_BOORDR_MD5="2b977246c13e88c1150b1e541fbd7f27"
STOCK_EBRMAIN_MD5="0a5518b05940030c0c24444dbed934a9"

fail=0
warn=0

ok()   { printf '  [ OK ] %s\n' "$*"; }
bad()  { printf '  [FAIL] %s\n' "$*"; fail=$((fail + 1)); }
note() { printf '  [WARN] %s\n' "$*"; warn=$((warn + 1)); }
sh_()  { "$ADB" shell "$1" 2>/dev/null | tr -d '\r'; }

echo "== Device =="

if ! command -v "$ADB" >/dev/null 2>&1 && [ ! -x "$ADB" ]; then
    bad "adb not found: $ADB"
    exit 1
fi

n=$("$ADB" devices 2>/dev/null | awk 'NR>1 && $2=="device"' | wc -l | tr -d ' ')
if [ "$n" -ne 1 ]; then
    bad "expected exactly 1 ADB device, found $n (enable ADB on the reader)"
    exit 1
fi
ok "one ADB device"

root=$(sh_ 'id')
case "$root" in
    *uid=0*) ok "ADB shell is root" ;;
    *) bad "ADB shell is not root (got: $root)" ;;
esac

kern=$(sh_ 'uname -r')
case "$kern" in
    3.0.8*) ok "kernel $kern" ;;
    *) bad "kernel is '$kern', expected 3.0.8+" ;;
esac

arch=$(sh_ 'uname -m')
[ "$arch" = "armv7l" ] && ok "armv7l" || bad "arch is '$arch', expected armv7l"

ver=$(sh_ 'cat /etc/version 2>/dev/null' | head -1)
[ "$ver" = "11" ] && ok "rootfs version 11" || bad "rootfs version is '$ver', expected 11"

sku=$(sh_ 'SN=$(nvram -s 2>/dev/null | cut -d= -f2); echo "$SN" | cut -c8-9')
[ "$sku" = "5F" ] && ok "SKU code '5F' (Odyssey HD FrontLight 2)" || bad "SKU code is '$sku', expected 5F (CYBOY5F)"

if sh_ 'pidof luajit' | grep -q .; then
    bad "KOReader is running; boot the stock reader first (koreader/.disabled + reboot)"
else
    ok "KOReader is not running"
fi

echo "== Stock software =="

if sh_ '[ -e /mnt/app/boordr ] && echo yes' | grep -q yes; then
    ok "/mnt/app/boordr exists"
else
    bad "/mnt/app/boordr is missing"
fi

shim=$(sh_ 'head -c 2 /mnt/app/boordr 2>/dev/null')
if [ "$shim" = "#!" ]; then
    note "/mnt/app/boordr is already a script (shim installed)"
    if sh_ '[ -e /mnt/app/boordr.stock ] && echo yes' | grep -q yes; then
        bmd5=$(sh_ 'md5sum /mnt/app/boordr.stock 2>/dev/null' | cut -d' ' -f1)
        what="/mnt/app/boordr.stock"
    else
        bad "/mnt/app/boordr is a shim but /mnt/app/boordr.stock is missing"
        bmd5=""
        what="/mnt/app/boordr"
    fi
else
    bmd5=$(sh_ 'md5sum /mnt/app/boordr 2>/dev/null' | cut -d' ' -f1)
    what="/mnt/app/boordr"
fi

if [ -n "$bmd5" ]; then
    if [ "$bmd5" = "$STOCK_BOORDR_MD5" ]; then
        ok "$what matches the tested stock reader"
    else
        note "$what md5 is $bmd5 (tested build: $STOCK_BOORDR_MD5). Different firmware build; continue only if you know it."
    fi
else
    note "could not read the stock reader md5"
fi

emd5=$(sh_ 'md5sum /mnt/app/ebrmain 2>/dev/null' | cut -d' ' -f1)
if [ -n "$emd5" ]; then
    if [ "$emd5" = "$STOCK_EBRMAIN_MD5" ]; then
        ok "ebrmain matches the tested build"
    else
        note "ebrmain md5 is $emd5 (tested build: $STOCK_EBRMAIN_MD5). Different firmware build."
    fi
fi

echo "== Conditions for a safe write =="

cap=$(sh_ 'cat /sys/class/power_supply/battery/capacity 2>/dev/null')
usb=$(sh_ 'cat /sys/class/power_supply/usb/online 2>/dev/null')
if [ -n "$cap" ] && [ "$cap" -ge 50 ] 2>/dev/null && [ "$usb" = "1" ]; then
    ok "battery ${cap}% and USB connected"
else
    bad "need battery >= 50% AND the USB cable connected (battery='${cap}', usb='${usb}')"
fi

rootfs=$(sh_ 'cat /proc/mounts' | awk '$1=="/dev/nandd" && $2=="/" {print $4}')
case "$rootfs" in
    *ro*) ok "/ is mounted read-only" ;;
    *) note "/ mount options: '$rootfs' (should be ro when idle)" ;;
esac

free_kb=$(sh_ 'df /' | tail -1 | awk '{print $4}')
if [ -n "$free_kb" ] && [ "$free_kb" -ge 20000 ] 2>/dev/null; then
    ok "rootfs free space ${free_kb} KB"
else
    bad "rootfs free space is '${free_kb}' KB (need >= 20000 KB)"
fi

fatopts=$(sh_ 'cat /proc/mounts' | awk '$2=="/mnt/fat" {print $4}')
case "$fatopts" in
    *rw*) ok "/mnt/fat is mounted rw" ;;
    *) bad "/mnt/fat is not mounted rw ('$fatopts')" ;;
esac

fatfree=$(sh_ 'df /mnt/fat' | tail -1 | awk '{print $4}')
if [ -n "$fatfree" ] && [ "$fatfree" -ge 300000 ] 2>/dev/null; then
    ok "/mnt/fat free space ${fatfree} KB"
else
    note "/mnt/fat free space is '${fatfree}' KB (KOReader needs about 90 MB)"
fi

if sh_ 'for f in /mnt/fat/CybUpdate.bin /mnt/sd/CybUpdate.bin /mnt/update/CybUpdate.bin; do [ -e "$f" ] && echo yes; done' | grep -q yes; then
    bad "a CybUpdate.bin is present; remove it before booting"
else
    ok "no CybUpdate.bin lying around"
fi

echo
if [ "$fail" -eq 0 ]; then
    echo "RESULT: all required checks passed ($warn warning(s))."
    exit 0
else
    echo "RESULT: $fail required check(s) FAILED. Do not change anything."
    exit 1
fi
