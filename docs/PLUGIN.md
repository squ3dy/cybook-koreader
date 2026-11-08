# Cybook menu plugin

The full release includes a small KOReader plugin:

```
koreader/plugins/cybook.koplugin/
```

It adds:

- **Tools → Cybook: USB, ADB, stock reader**
- **Tools → Cybook: performance**
- **Tools → Cybook: Home button**
- a reader Home-button **Quick Menu**

The mode-switching part does not talk to the hardware directly. It writes a request to
`/tmp/cybook-mode` and asks KOReader to exit. The `/mnt/app/boordr` shim reads the request,
performs the operation, and relaunches KOReader when appropriate.

## Home Quick Menu

While reading, the physical Home button opens a fixed menu:

```
Frontlight        Night mode
Table of contents Rotate
Full refresh      Dictionary
File browser      (full-width row)
```

- **Frontlight** opens a slider snapped to levels 1–10. The label shows `N/10`, `Min`
  or `Off`.
  - **Min** sets the native hardware minimum (`1/255`), dimmer than level 1.
  - **Off/On** turns the light off and restores the last level.
  - **Max** sets level 10.
  - `−`/`+` and the side page-turn buttons move one level. Left at level 1 goes to
    Min; right at Min goes to level 1.
  - Home, Back, Close, or tapping outside closes the slider.
- **Night mode**, **Rotate**, **Full refresh** and **Dictionary** use the normal
  KOReader actions.
- **Table of contents** opens the reader TOC.
- **File browser** closes the book and opens the file manager.

The Quick Menu is reader-only. File-manager Home behavior is unchanged when no menu is
open. The toggle and preview are under **Tools → Cybook: Home button**.

## Home as Back

When a menu or dialog is open, Home acts as Back instead of reopening the Quick Menu.
It backs out one level at a time in both the reader and the file manager:

- settings/TouchMenu: up one level, then close
- TOC/Menu: up one level, then close
- input, dictionary, confirmation and spin dialogs: close or cancel
- Quick Menu and frontlight: close
- file-manager menus: up one level / close

Screen-saver windows are not dismissed by Home. With no menu open, Home still opens the
Quick Menu in the reader and goes to the home folder in the file manager.

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

USB/ADB/stock and the performance menu were introduced in v0.2.0/v0.3.0. The Home Quick
Menu, frontlight slider and Home-as-Back are new in v0.6.0. Verify them on your unit
before relying on them.

The frontlight slider uses the stock `/bin/frontlight` interface and assumes the
`gt80x` touchscreen and page-turn keys of the `CYBOY5F`. Other Bookeen models may map
keys differently.

The performance menu hides CPU/I/O controls the kernel does not expose. Test one change
at a time, and keep `performance` governor for when you are plugged in until you know
the battery cost.
