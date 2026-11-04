# How it works

## Boot chain

On this device the stock chain is roughly:

```
U-Boot
  └─ Linux 3.0.8
      └─ /sbin/init
          ├─ /etc/init.d/S11cyevd.sh   → cyevd (input daemon)
          └─ /etc/init.d/S99ebrmain.sh → ebrmain (supervisor)
                                            └─ boordr (stock reader)
```

`ebrmain` is the supervisor. It looks for a reader binary named `boordr` in several
places, in this order:

```
/mnt/sd/boordr
/mnt/fat/boordr
/mnt/app/boordr
```

It also looks for a hook file named `cybook_upgrade` in the FAT/SD roots:

```
/mnt/sd/cybook_upgrade
/mnt/fat/cybook_upgrade
/mnt/ext2/cybook_upgrade
/mnt/ext1/cybook_upgrade
```

The hook is executed once as root at startup and then removed. This is the mechanism
the installer uses when it is copied to the FAT root.

## What the installer does

`installer/cybook_upgrade`:

1. Verifies `/mnt/fat/koreader/koreader.sh`.
2. Remounts `/` read-write.
3. Hard-links the stock reader to `/mnt/app/boordr.stock` (no extra space).
4. Writes the shim to `/mnt/app/boordr.new`, then atomically renames it to
   `/mnt/app/boordr`. The original path is never missing, even if power fails.
5. Remounts `/` read-only and writes `/mnt/fat/koreader-install.log`.

The bootloader, kernel, and NAND firmware are never touched.

## What the shim does

The shim is the first thing `ebrmain` executes instead of the stock reader:

```sh
if koreader/koreader.sh exists and koreader/.disabled does not exist:
    kill cyevd
    run koreader.sh
    if the plugin requested "usb" or "adb":
        unmount /mnt/fat, start the stock USB gadget, wait for unplug
        stop the gadget, mount /mnt/fat, run KOReader again
    if the plugin requested "stock":
        create koreader/.disabled, restart cyevd, exec the stock reader
    if KOReader failed twice quickly:
        create koreader/.disabled, restart cyevd on the next relaunch
    exit 101 on clean exit, 11 otherwise
else:
    restart cyevd if needed
    exec /mnt/app/boordr.stock "$@"
```

The exit codes are Bookeen's: `101` means "power off after a clean reader exit";
`11` asks `ebrmain` to relaunch. The safety switch counts failures in
`koreader/.fails`: two errors in a row, each shorter than 120 seconds, create
`koreader/.disabled` so the next relaunch starts the stock reader.

`/mnt/fat/koreader/mode.log` records USB/ADB mode requests and failures.

## Why `cyevd` must be stopped

The stock input daemon `cyevd` opens and exclusively grabs:

```
/dev/input/event0   face buttons (Menu, Back, Next)
/dev/input/event1   power button
/dev/input/event2   touchscreen (gt80x)
```

The kernel still lets KOReader open these devices, but no events are delivered while
`cyevd` holds the grab. That is why a manual KOReader launch shows the UI but touch and
buttons do nothing.

The shim runs `killall cyevd` before KOReader and restarts `cyevd` for the stock
fallback. The stock `cyevd` is started normally by `S11cyevd.sh` at boot; the shim
takes over only after that.

## Files changed

```
/mnt/app/boordr             shim
/mnt/app/boordr.stock       original stock reader
/mnt/fat/koreader/          KOReader
/mnt/fat/koreader/plugins/cybook.koplugin/
/mnt/fat/koreader-install.log
```

Optional files:

```
/mnt/fat/adb_debug          enables the hidden ADB menu item
/mnt/fat/koreader/.disabled boots the stock reader instead
/mnt/fat/koreader/.fails    KOReader crash counter
/mnt/fat/koreader/mode.log  USB/ADB mode log
```

## Why this is not a custom firmware

A real CFW would replace the kernel, bootloader, or NAND rootfs. Here, the stock
rootfs is unchanged except for the `boordr` rename and the small launcher. Removing the
shim and renaming `boordr.stock` back restores the stock reader exactly.

## Limitations

- KOReader itself has no USB gadget. The plugin asks the shim to unmount `/mnt/fat`,
  start the stock `mass_storage.sh`, and relaunch KOReader after unplugging. This is
  not a native KOReader USB mode, and it is untested on this exact model.
- Adobe ADEPT DRM is not supported by KOReader. Use the stock reader for DRM books.
- This is a custom KOReader build. Automatic update checks are not useful; update by
  replacing the `koreader` folder.
- Wi-Fi, suspend, and some device-specific features are ported but not exhaustively
  tested on every CYBOY5F revision.
