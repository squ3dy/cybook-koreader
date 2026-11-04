# KOReader for the Cybook Odyssey HD FrontLight 2

A reversible boot shim that runs [KOReader](https://koreader.rocks/) on the Bookeen
Cybook Odyssey HD FrontLight 2 (`CYBOY5F`) and keeps the stock Bookeen reader as a
fallback.

This is not a firmware image. The bootloader, kernel and NAND are untouched. The only
change outside the user partition is the launcher at `/mnt/app/boordr`; the original
40 MB stock reader stays on the device as `/mnt/app/boordr.stock`.

Tested on one device: `CYBOY5F`, firmware build 11 (Feb 2015), Linux 3.0.8+, AllWinner
A13, 758×1024 screen, glibc 2.11.1. Other Bookeen models may work, but are untested.
Back up your books before starting; recovery is possible but not guaranteed.

## What it does

- Runs KOReader from `/mnt/fat/koreader` instead of the stock reader.
- Stops `cyevd` while KOReader runs. The stock daemon grabs `event0/1/2` exclusively;
  without this, KOReader opens the input devices but receives no touch or button events.
- Restarts `cyevd` when falling back to the stock reader.
- Adds a KOReader menu for USB mass storage, ADB, returning to stock, and performance
  tuning.
- Falls back to stock automatically after two quick KOReader crashes.
- Keeps the original reader at `/mnt/app/boordr.stock`.

## Before installing

1. Copy the whole `Cybook` volume to your computer.
2. Free at least 100 MB on the reader.
3. Prepare a microSD recovery card if you can; see [docs/RECOVERY.md](docs/RECOVERY.md).

## Install

1. Download `cybook-koreader-full-*.zip`. It contains KOReader, the installer and the
   Cybook plugin.
2. Extract it into the **root** of the `Cybook` volume. You should end up with:
   ```
   Cybook/cybook_upgrade
   Cybook/koreader/koreader.sh
   ```
3. Eject the volume, unplug USB, and reboot.
4. Bookeen's supervisor runs `cybook_upgrade` once and removes it. KOReader starts.
5. On first start, set the home folder to your books, for example `Книжки`.

The installer writes `/mnt/fat/koreader-install.log`. If KOReader does not start, boot
the stock reader and read that log over USB.

## Daily use

**USB mode** — copy books without rebooting:

**Tools → Cybook: USB, ADB, stock reader → USB mode**

KOReader closes, unmounts `/mnt/fat` and exposes it as a USB drive. Copy books, eject
from the computer, then unplug. KOReader returns automatically. Do not unplug before
ejecting; the FAT partition is exported as a block device.

**Back to stock** — use the same menu. It creates `koreader/.disabled`, restarts
`cyevd` and starts the stock reader. Delete `.disabled` to return to KOReader.

**Performance** — see [docs/PERFORMANCE.md](docs/PERFORMANCE.md). The short version:
disable Cover Browser, disable unused plugins, apply the fast UI profile, set full
refresh to every 6 pages, keep Wi-Fi off, and test suspend before relying on it.

## Updating

Boot the stock reader (plugin → Back to stock, or create `koreader/.disabled` and
reboot). Extract the latest full zip over the volume, reboot once, then remove
`koreader/.disabled`. The root `cybook_upgrade` refreshes the shim; the plugin is
replaced too.

For a normal KOReader-only update, replace the `koreader` folder while in stock. The
full zip includes the plugin; if you use the separate KOReader zip, keep
`koreader/plugins/cybook.koplugin` in place.

## Uninstall

With ADB root, while the stock reader is running:

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

## Recovery

Read [docs/RECOVERY.md](docs/RECOVERY.md) before you need it. It covers the `.disabled`
marker, the microSD `cybook_upgrade` recovery hooks, and restoring the stock reader via
ADB.

## Build

```sh
./scripts/build-koreader.sh
```

This uses the official `koreader/kobookeen` Docker image and the KOReader `bookeen`
target. The build directory is kept in `/tmp/cybook-koreader-build` so compiled paths do
not contain your home directory. See [docs/BUILDING.md](docs/BUILDING.md) for the
`download.gnome.org` workaround and release packaging.

## Documentation

- [Install](docs/INSTALL.md)
- [Cybook plugin](docs/PLUGIN.md)
- [Performance](docs/PERFORMANCE.md)
- [How it works](docs/HOW-IT-WORKS.md)
- [Recovery](docs/RECOVERY.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Building](docs/BUILDING.md)
- [Device notes](docs/DEVICE-NOTES.md)
- [KOReader settings](docs/SETTINGS.md)

## Credits and license

KOReader and its Bookeen target are maintained by the KOReader project. The
mode-switching shim, plugin and preflight ideas are adapted from
[bruthethe/saraiva-lev-koreader](https://github.com/bruthethe/saraiva-lev-koreader);
see [CREDITS.md](CREDITS.md).

Code and documentation are AGPL-3.0-or-later; see [LICENSE](LICENSE). The exact
KOReader source revision is recorded in [SOURCE.md](SOURCE.md).
