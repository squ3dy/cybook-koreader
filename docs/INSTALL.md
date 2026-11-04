# Install

## Preparation

Copy the whole `Cybook` volume to your computer. It is your book backup and the easiest
way back if something goes wrong. Leave at least 100 MB free on the reader. If you have a
small microSD card, prepare a recovery card as described in [RECOVERY.md](RECOVERY.md).

The installer was tested on `CYBOY5F`, firmware build 11 (Feb 2015). Do not use it on a
different model unless you are prepared to recover the device.

## No ADB (recommended)

1. Download `cybook-koreader-full-*.zip`, or the separate `koreader-bookeen-*.zip` and
   `cybook-koreader-installer-*.zip`.
2. Extract the full zip into the **root** of the `Cybook` volume. The result must be:
   ```
   Cybook/cybook_upgrade
   Cybook/koreader/koreader.sh
   ```
   With the separate assets, extract the KOReader zip first, copy `cybook_upgrade` to
   the root, and copy `plugin/cybook.koplugin` to `koreader/plugins/`.
3. Eject the volume, unplug USB, and reboot.
4. Bookeen's supervisor runs `cybook_upgrade` once as root, then removes it. KOReader
   starts.
5. Set the home folder to your books, for example `Книжки`.

The installer log is `Cybook/koreader-install.log`. If KOReader does not start, boot the
stock reader, connect USB, and read it.

## ADB

ADB is optional. It is useful for updates, logs and recovery.

1. Create an empty file named `adb_debug` in the root of the `Cybook` volume.
2. On the reader: **Menu → Settings → Enable ADB**.
3. Connect USB and do not mount the volume.
4. Run:
   ```sh
   ./scripts/install-via-adb.sh --zip /path/to/koreader-bookeen-*.zip
   ```
   The installer runs a read-only preflight check, pushes KOReader and the plugin, and
   refreshes the shim. Use `--skip-preflight` only if you know why a check failed.
5. Reboot.

The ADB installer refuses to run while KOReader is active. Boot the stock reader first.

## Updating

Boot the stock reader, extract the latest full zip over the volume, and reboot once.
The root `cybook_upgrade` refreshes `/mnt/app/boordr` and replaces the plugin. Remove
`koreader/.disabled` to start KOReader.

For a KOReader-only update, replace the `koreader` folder while in stock. Keep
`koreader/plugins/cybook.koplugin` if you use the separate KOReader zip.

## USB mode

From KOReader:

**Tools → Cybook: USB, ADB, stock reader → USB mode**

KOReader closes and unmounts `/mnt/fat`, then exports it as a USB drive. Copy books,
**eject from the computer**, and unplug. KOReader returns automatically. Never unplug
before ejecting.

## Stock reader and uninstall

To boot stock temporarily, create an empty file:

```
Cybook/koreader/.disabled
```

Reboot. The shim restarts `cyevd` and starts the stock reader. Remove the file to return
to KOReader. The plugin's **Back to stock** item does the same thing.

To remove the shim, with ADB root and the stock reader running:

```sh
./scripts/uninstall-via-adb.sh --purge --reboot
```

Or manually:

```sh
mount -o remount,rw /
mv -f /mnt/app/boordr.stock /mnt/app/boordr
sync
mount -o remount,ro /
reboot
```

Then delete the `koreader` folder from the user partition if desired.

## First run

Set the home folder to your library, for example `Книжки`. Turn off page-turn animations
and cover thumbnails, set full refresh to every 6 pages, and test suspend before enabling
auto-suspend. See [SETTINGS.md](SETTINGS.md) and [PERFORMANCE.md](PERFORMANCE.md).
