# Device notes

## Tested unit

| Item | Value |
|---|---|
| Model | Cybook Odyssey HD FrontLight 2 (`CYBOY5F`) |
| SoC | AllWinner A13, ARMv7, 1 GHz |
| RAM | 256 MB |
| Screen | 6", 758×1024, 16-level grayscale, frontlight |
| Storage | 2.8 GB internal FAT user partition, microSD slot |
| Audio | none on this model |
| Accelerometer | none |
| Firmware | `/etc/version` = `11`, `/etc/br-version` = `2011.02` |
| Kernel | Linux `3.0.8+ #1 PREEMPT Thu Feb 26 09:35:27 CET 2015` |
| libc | glibc 2.11.1 (`ld-2.11.1.so`) |
| Boot | Bookeen `ebrmain` supervisor + `boordr` |

The serial-number structure is documented in KOReader's
`frontend/device/bookeen/device.lua`. The tested model is `CYBOY5F-BK`; other revisions
may differ.

## Partitions and mounts

```
/dev/nandd   ext4, read-only rootfs, ~216 MB   /
/dev/nande   vfat, ~32 MB                     /priv
/dev/fat     vfat, ~2.6 GB                    /mnt/fat
/dev/mmcblk0p1                                /mnt/sd (when present)
```

The stock rootfs is read-only during normal operation. The installer remounts it
read-write briefly to rename `boordr`, then remounts it read-only.

## Display

```
/dev/fb0     8 bpp, virtual 1024×1516
/dev/disp    Bookeen e-ink update ioctl
```

The visible panel is 758×1024. KOReader uses the Bookeen `mxcfb`-compatible
framebuffer path and sends updates through `/dev/disp`.

## Input

```
event0  sun4i-keyboard   Menu (139), Back (158), Next (407)
event1  axp20-supplyer   Power (116)
event2  gt80x            touchscreen
```

`cyevd` opens all three and holds an exclusive grab. This is the key device-specific
issue: KOReader must run after `killall cyevd`. The shim handles it.

The touch controller is a Goodix `gt80x`, not the `cyttsp4` or `Goodix-TS` used on
some other Bookeen models. The upstream Bookeen input handler works, but multitouch
should be treated as experimental.

## Frontlight

```
/bin/frontlight        value 0..255, inverted internally
/bin/eink              draws a BMP splash
```

KOReader's Bookeen power driver calls `/bin/frontlight`. The frontlight is a separate
rail and stays lit across suspend, so KOReader explicitly zeroes it before suspend and
restores it after resume.

## Boot hooks

`ebrmain` searches for `boordr` in this order:

```
/mnt/sd/boordr
/mnt/fat/boordr
/mnt/app/boordr
```

It also executes a hook named `cybook_upgrade` from the FAT/SD roots once at boot:

```
/mnt/sd/cybook_upgrade
/mnt/fat/cybook_upgrade
/mnt/ext2/cybook_upgrade
/mnt/ext1/cybook_upgrade
```

The hook runs as root and is removed after execution. This is why the installer can be
installed without ADB.

## What was tested

- KOReader display, touch, side page buttons, Menu button, frontlight: working.
- Boot shim installation and automatic KOReader start: working.
- Stock reader preserved as `/mnt/app/boordr.stock`: verified.
- ADB root access via `adb_debug` + Settings → Enable ADB: working.
- `cyevd` input grab identified and handled: verified manually.
- Plugin USB/ADB/stock modes and the automatic crash switch: **ported from the Lev
  project, not yet tested on this unit**.
- Performance menu (CPU governor, NAND scheduler/read-ahead, Cover Browser toggle, fast
  UI profile): **implemented, not yet exercised on this unit**. The menu hides controls
  the kernel does not expose.
- `scripts/preflight.sh`: not run on a device yet; read-only.
- Suspend/resume, Wi-Fi, OPDS/Calibre, SD-card recovery, and Adobe DRM: **not tested**
  on this unit.

## Compatibility warning

This installer is deliberately small, but the stock firmware versions differ between
Bookeen models and production batches. If your `/etc/version` is not `11`, or your
device is not a `CYBOY5F`, make a full backup and prepare the recovery SD card first.
