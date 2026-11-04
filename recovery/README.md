# Recovery card

These are emergency `cybook_upgrade` hooks for a FAT32 microSD card.

## Disable KOReader (boot stock)

1. Copy `disable-koreader` to the root of the SD card.
2. Rename it to exactly `cybook_upgrade` (no extension).
3. Insert the card and boot the reader.
4. The hook creates `/mnt/fat/koreader/.disabled` and reboots to the stock reader.
5. Remove the card.

## Restore stock permanently

1. Copy `restore-stock` to the root of the SD card.
2. Rename it to exactly `cybook_upgrade`.
3. Insert the card and boot the reader.
4. The hook removes the shim and restores `/mnt/app/boordr` from
   `/mnt/app/boordr.stock`, then reboots.
5. Remove the card.

`restore-stock` refuses to run if `boordr.stock` is missing.

## Notes

- The SD card must be FAT32 and simple. Small old cards work best.
- The `cybook_upgrade` hook is proven on the internal FAT partition. The SD path is
  present in the stock `ebrmain` binary, but the exact SD recovery flow has not been
  tested on a bricked unit. Test it once before you need it, if possible.
- The hook may rename itself to `cybook_upgrade.done`; that is intentional, to avoid a
  reboot loop. Remove the card after the reboot.
- If the device does not boot at all, use the official Bookeen firmware update for
  your exact model. This repository does not include firmware images.
