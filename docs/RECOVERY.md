# Recovery

Keep two things before you experiment:

1. A full copy of the `Cybook` volume on your computer.
2. A small FAT32 microSD card with a recovery `cybook_upgrade` file.

The microSD recovery uses the same `cybook_upgrade` hook that the installer uses. The
hook itself is proven on this device from the FAT partition. The SD path is present in
the stock `ebrmain` binary, but the exact SD recovery flow has not been tested on a
bricked unit. Test it once while the device still boots, if you can.

## 1. KOReader works, but you want the stock reader

From KOReader:

**Tools → Cybook: USB, ADB, stock reader → Back to the stock reader**

That creates `koreader/.disabled`, restarts `cyevd`, and starts the stock reader.

Alternatively, create the file over USB or from the Terminal plugin:

```sh
touch /mnt/fat/koreader/.disabled
```

Then reboot.

If KOReader crashes twice in a row, each time within 120 seconds, the shim creates
`.disabled` automatically and the next relaunch starts the stock reader.

## 2. KOReader hangs or shows a blank screen

1. Hold the power button until the device powers off.
2. Prepare a FAT32 microSD card with the file `recovery/disable-koreader` in the
   **root**, renamed to exactly:
   ```
   cybook_upgrade
   ```
   No extension.
3. Insert the card and boot the device.
4. The stock supervisor runs the hook, which creates `koreader/.disabled` and reboots.
5. Remove the SD card. The stock reader should start.
6. The `.disabled` file is still on the internal volume. Connect USB from the stock
   reader and delete it when you want KOReader again.

## 3. Restore the stock reader permanently

Use this to remove the shim and return to the stock reader.

1. Prepare a FAT32 microSD card with `recovery/restore-stock` in the root, renamed to:
   ```
   cybook_upgrade
   ```
2. Insert the card and boot.
3. The hook remounts `/` read-write, removes the shim, moves `/mnt/app/boordr.stock`
   back to `/mnt/app/boordr`, remounts read-only, and reboots.
4. Remove the SD card.

`restore-stock` refuses to do anything if `/mnt/app/boordr.stock` is missing. That
protects you from deleting the only reader.

## 4. ADB is available

If the stock reader boots and you can enable ADB, use:

```sh
./scripts/disable-koreader.sh --reboot
./scripts/enable-koreader.sh --reboot
./scripts/uninstall-via-adb.sh --purge --reboot
```

They require ADB root and, for uninstall, the stock reader running.

## 5. Nothing works: official firmware update

The last-resort recovery is Bookeen's official updater:

- Copy a correct `CybUpdate.bin` for your exact model to a small FAT32 microSD card.
- Insert it and boot. The stock updater should offer the update.
- Do **not** use a `CybUpdate.bin` for another model.

This repository does not include a firmware image. Ask Bookeen support for the correct
`CybUpdate.bin` / recovery image for `CYBOY5F`, or use a known-good image from your own
backup. AllWinner devices can often be recovered with FEL/PhoenixTools, but that
requires the correct image and is outside the scope of this project.

## 6. If `boordr.stock` is gone

The stock binary is proprietary and is not distributed here. If it is missing, you
need:

- a copy of `/mnt/app/boordr` from your own backup, or
- the official Bookeen firmware image for your model.

The installer renames the original; it does not delete it. Do not remove
`/mnt/app/boordr.stock` unless you have another copy.

## Prepare the recovery card now

```sh
# On a FAT32 microSD card mounted at /Volumes/RECOVERY:
cp recovery/disable-koreader /Volumes/RECOVERY/cybook_upgrade
sync
diskutil eject /dev/diskN
```

Label the card so you know what it does. Keep it with the reader.
