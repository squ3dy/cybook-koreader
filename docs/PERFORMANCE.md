# Performance

The limiting factors are a single-core AllWinner A13, 256 MB RAM, a FAT user partition,
and e-ink refresh. Most perceived slowness comes from background work, full-screen
refreshes, and the first render of a document — not from the CPU alone.

## Start here

1. **Disable Cover Browser.** It is the largest avoidable RAM/CPU cost.
   **Tools → Cybook: performance → Disable Cover Browser (faster)**
2. **Disable unused plugins.** Every `*.koplugin` directory is loaded at startup.
   **Tools → Plugin management**
3. **Apply the fast UI profile.**
   **Tools → Cybook: performance → Apply fast UI profile**
4. **Set full refresh to every 6 pages.**
   **Settings → Screen → E-ink settings → Full refresh rate**
5. **Keep Wi-Fi off** while reading.
6. **Keep about 300 MB free** on the FAT partition.

Restart KOReader after changing the panning/profile setting.

## UI and e-ink

In **Settings → Screen → E-ink settings**:

- Use smaller panning rate: on
- Avoid mandatory black flashes in UI: on
- Full refresh rate: every 6 pages

In **Settings → Page turns**, turn off page-turn animations. Full refresh on every page
is slower; “never” is faster but builds ghosting.

In **Settings**, use a minimal status bar and full screen. Set **Start with: most recent
document** if you usually resume the same book.

Keep one font family and size for a while. Changing font, margins or line spacing forces
KOReader to re-render the whole EPUB.

## CPU governor

**Tools → Cybook: performance → CPU governor**

`ondemand` is the normal battery-friendly choice. `performance` keeps the A13 at maximum
frequency and makes menus/page turns feel quicker, at the cost of heat and battery. Use
it while plugged in, or for a heavy PDF, and switch back when done. The setting is saved
and re-applied when KOReader starts.

## NAND scheduler and read-ahead

**Tools → Cybook: performance → I/O scheduler (NAND)**

`noop` is usually a good choice for raw flash. `deadline` is a reasonable alternative.
`cfq` adds overhead and is designed for rotating disks; it is rarely the best option
here.

**Tools → Cybook: performance → Read-ahead (NAND)**

Try 128, 256 and 512 KB with the same book. Larger values can help sequential reads but
waste page cache. Bigger is not automatically faster.

## Memory

KOReader sizes its document cache from free RAM: 16 MB minimum, 40% of free memory by
default, 512 MB maximum. That is reasonable on this device. Cover Browser, metadata
extraction and unused plugins are the main avoidable users.

Do not add a swap file on FAT. If the kernel exposes `zram`, a small compressed swap
(32–64 MB) may help very large PDFs, but it costs CPU; treat it as experimental. The
performance status screen shows whether `zram` exists.

## EPUB and PDF

An EPUB is laid out and indexed on first open. The second open is much faster. Changing
font or layout re-renders it. Very large single-file EPUBs are inherently slow; split
them or convert them with Calibre.

For PDFs, lower **Document → Quality** to 0.5–0.8 for large or scanned files. Use page
crop for wide margins, and reflow only for text-heavy PDFs. Comics and complex layouts
should use page-fit/width without reflow. A 100 MB PDF will still be slow; prefer EPUB
for text.

## Measuring

**Tools → Cybook: performance → Performance status** shows the governor, frequency, NAND
scheduler, read-ahead, RAM/swap, Cover Browser state and load average.

Use one EPUB and one PDF, time the first open and a warm reopen, then page through 20
pages. Change one setting at a time. Cold and warm results are different; do not judge
the device by the first open of a large book.

## Build notes

The Bookeen target already uses the right flags:

```
-march=armv7-a -mtune=cortex-a8 -mfpu=neon -mthumb -mfloat-abi=softfp
-O2 -pipe -fomit-frame-pointer
```

Selected components use `-O3` and vectorization. A newer KOReader master is the safest
experiment. `CI=1` removes debug info and shrinks the package but has little runtime
effect. Global `-O3` and LTO are experimental and can make things worse.

Do not overclock, repartition NAND, or replace the kernel for a small UI gain.

## Avoid

- Full refresh on every page.
- Unloading `udev`, `ctp` or `kfusd`.
- Keeping `cyevd` stopped in the stock reader.
- Swap on FAT.
- Clearing caches constantly.
- Judging performance by a cold open of a large EPUB.

## Sources

- KOReader: `defaults.lua`, `frontend/document/doccache.lua`,
  `frontend/ui/elements/screen_eink_opt_menu_table.lua`,
  `frontend/ui/elements/refresh_menu_table.lua`, `base/Makefile.defs`
- KOReader user guide: <https://koreader.rocks/user_guide/>
- Allwinner cpufreq:
  <https://github.com/allwinner-dev-team/linux-allwinner/tree/allwinner-3.0/Documentation/cpu-freq>
- Saraiva Lev KOReader notes:
  <https://github.com/bruthethe/saraiva-lev-koreader>
