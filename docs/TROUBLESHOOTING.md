# Troubleshooting

## Touch or buttons do nothing

The stock `cyevd` daemon grabs `/dev/input/event0/1/2` exclusively. KOReader can open
the devices but receives no events.

Check from ADB root:

```sh
pidof cyevd
```

If it is running while KOReader is active, stop it:

```sh
killall cyevd
```

The installed shim does this automatically. If you launch KOReader manually, run
`killall cyevd` first.

## KOReader does not start after install

1. Boot the stock reader (create `koreader/.disabled` on the FAT volume, reboot).
2. Check the install log:
   ```
   koreader-install.log
   ```
3. Check that the shim exists and is executable:
   ```sh
   ls -l /mnt/app/boordr /mnt/app/boordr.stock
   ```
4. Check that KOReader is complete:
   ```sh
   ls -l /mnt/fat/koreader/koreader.sh /mnt/fat/koreader/luajit
   ```
5. Read `/mnt/fat/koreader/crash.log`.

Common causes:

- The KOReader zip was extracted one level too deep. The path must be
  `/mnt/fat/koreader/koreader.sh`, not `/mnt/fat/koreader/koreader/koreader.sh`.
- The FAT volume is full.
- The installer was copied but never executed (check `cybook_upgrade` was in the FAT
  root and the device was rebooted).
- `boordr.stock` is missing; see [RECOVERY.md](RECOVERY.md).

## KOReader hangs or shows a blank screen

Force power off, then use the recovery SD card described in
[RECOVERY.md](RECOVERY.md). Do not repeatedly power-cycle and hope; use the
`disable-koreader` hook.

## ADB does not appear

- Create an empty file named `adb_debug` in the FAT root.
- On the reader: **Menu → Settings → Enable ADB**.
- ADB is not auto-started at boot. It must be enabled each time from the stock reader.
- Check the cable and use a data cable, not a charge-only cable.
- On macOS, use `platform-tools/adb devices -l`.

## `adb shell` is not root

The Bookeen ADB implementation normally gives root. If `id` does not show `uid=0`,
stop and do not run the installer; find out what changed.

## USB mass storage is not available in KOReader

KOReader itself does not export the FAT partition. Use:

**Tools → Cybook: USB, ADB, stock reader → USB mode**

The shim unmounts `/mnt/fat`, starts the stock `mass_storage.sh`, waits for unplug, and
relaunches KOReader. Eject from the PC first.

If the mode fails, check `/mnt/fat/koreader/mode.log`. A busy `/mnt/fat` is the usual
cause. The fallback is to boot the stock reader with `.disabled`, copy files, then
remove `.disabled`.

## The Cybook plugin menu is missing

- The plugin lives in `/mnt/fat/koreader/plugins/cybook.koplugin/`.
- The full release zip includes it; the separate KOReader zip does not.
- Copy it from `plugin/cybook.koplugin`, or use the ADB installer.
- Restart KOReader after copying it.

## Preflight fails

`scripts/preflight.sh` is read-only. It checks model, firmware build 11, battery, USB,
free space, and the stock reader. If a required check fails, fix it or use
`--skip-preflight` only if you understand why. A different firmware build may still
work, but it is untested.

## Suspend does not wake

The Bookeen power driver is old. Test suspend once with a short timeout. If the device
does not wake reliably, disable auto-suspend and use power-off instead. The
`autosuspend` plugin is enabled only when the device reports suspend support.

## Wi-Fi is flaky

The Bookeen Wi-Fi scripts are from 2015. The KOReader port includes `wlan.sh` and
`restore-wifi-async.sh`, but Wi-Fi behavior varies. Keep Wi-Fi off while reading; turn
it on only for OPDS/Calibre/sync.

## Clock is wrong and HTTPS/SSL fails

The device may reset to 2015 after a recovery. Set the clock from ADB root:

```sh
date -u -s "2026-11-01 12:00:00"
hwclock -w -u
```

## Updates

This is a custom build. Automatic update checks are not useful; turn them off.
Update by replacing the `koreader` folder while booted into the stock reader.

## DRM books do not open

KOReader does not support Adobe ADEPT DRM. Use the stock reader for DRM-protected
EPUB/PDF files.
