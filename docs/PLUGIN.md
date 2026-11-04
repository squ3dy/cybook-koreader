# Cybook menu plugin

The full release includes a small KOReader plugin:

```
koreader/plugins/cybook.koplugin/
```

It adds **Tools → Cybook: USB, ADB, stock reader** to KOReader.

The plugin does not talk to the hardware directly. It writes a request to
`/tmp/cybook-mode` and asks KOReader to exit. The `/mnt/app/boordr` shim reads the request,
performs the operation, and relaunches KOReader when appropriate.

## USB mode (mass storage)

1. In KOReader: **Tools → Cybook: USB, ADB, stock reader → USB mode**.
2. Confirm. KOReader closes and the FAT partition is unmounted.
3. Connect the USB cable. The reader appears as a USB drive on the PC.
4. Copy books.
5. **Eject the drive from the PC**, then unplug the cable.
6. The shim stops mass storage, mounts the FAT partition again, and relaunches KOReader.

The FAT partition is explicitly unmounted before it is exported. Do not skip the eject
step; writing from the PC and the device at the same time can corrupt FAT.

If the mode fails, it is logged to:

```
koreader/mode.log
```

and KOReader is relaunched. A common reason is that a process still has `/mnt/fat`
mounted/busy.

## ADB mode

1. In KOReader: **Tools → Cybook: USB, ADB, stock reader → Enable ADB**.
2. Confirm. KOReader closes and starts `adbd`.
3. Connect USB and use `adb`.
4. Unplug the cable. The shim stops ADB and relaunches KOReader.

USB mass storage and ADB are mutually exclusive on this hardware; the stock scripts
stop one before starting the other.

## Back to the stock reader

1. In KOReader: **Tools → Cybook: USB, ADB, stock reader → Back to the stock reader**.
2. Confirm. KOReader closes, creates `koreader/.disabled`, restarts `cyevd`, and starts
   the stock reader.

To return to KOReader, delete `koreader/.disabled` (the stock USB drive is the easiest
way) and reboot.

## Performance menu

The plugin also adds:

**Tools → Cybook: performance**

- **Performance status** — CPU governor/frequency, NAND scheduler, read-ahead, RAM,
  swap/zram, Cover Browser state, KOReader revision, load average.
- **CPU governor** — switch between the governors the kernel exposes. `performance`
  is faster but drains the battery and produces more heat.
- **I/O scheduler (NAND)** — `noop`/`deadline`/`cfq` if available.
- **Read-ahead (NAND)** — 128/256/512/1024 KB.
- **Disable Cover Browser (faster)** — removes cover/metadata extraction; restart
  required.
- **Apply fast UI profile** — smaller panning, no swipe animations, no forced UI
  flashes, start with last book.

CPU, I/O and read-ahead settings are saved and re-applied when KOReader starts. The
menu hides unavailable controls automatically. See [PERFORMANCE.md](PERFORMANCE.md)
for the research and trade-offs.

## Safety switch

If KOReader exits with an error twice in a row, each time within 120 seconds, the shim
creates `koreader/.disabled` automatically and falls back to the stock reader on the
next supervisor relaunch. Delete `.disabled` after fixing the problem.

## Installing the plugin manually

If you used the separate KOReader zip rather than the full release zip:

1. Copy `plugin/cybook.koplugin` from the installer zip to:
   ```
   koreader/plugins/cybook.koplugin
   ```
2. Reboot KOReader.

The ADB installer copies it automatically.

## Status

The plugin is ported from the Saraiva Lev project, where the USB mode was tested. On
`CYBOY5F` it is **not yet tested by this project**. USB mode uses the same stock
`mass_storage.sh` and the same unmount-first logic, so it should behave the same, but
verify it with a non-critical book first.

The performance menu is new and untested on this unit. The menu hides CPU/I/O controls
the kernel does not expose. Test one change at a time, and keep `performance` governor
for when you are plugged in until you know the battery cost.
