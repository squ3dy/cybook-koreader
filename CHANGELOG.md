# Changelog

## v0.6.0 — 2026-11-08

- New reader **Home-button Quick Menu** with seven actions: Frontlight, Night mode,
  Table of contents, Rotate, Full refresh, Dictionary, and File browser.
- New frontlight dialog with a slider snapped to 10 levels:
  - **Min** sets the native hardware minimum (`1/255`), below level 1.
  - **Off/On** turns the light off and restores the last level.
  - **Max** sets level 10; `−`/`+` move one level.
  - The side page-turn buttons lower/raise brightness while the dialog is open.
- **Home acts as Back** in menus and dialogs, one level at a time, in both the reader
  and the file manager. While backing out, the Quick Menu no longer opens.
- Setting: **Tools → Cybook: Home button** with a Quick Menu toggle and preview.
- Plugin-only release: no KOReader rebuild, shim change, kernel, bootloader or NAND
  modification.
- Consolidates internal 0.4.0–0.6.0 builds into the first published Home-menu release.

## v0.3.0 — 2026-11-04

- New **Cybook: performance** menu:
  - performance status (CPU, NAND scheduler, read-ahead, RAM, swap/zram, load)
  - CPU governor selection (including `performance`)
  - NAND I/O scheduler selection
  - NAND read-ahead selection
  - Cover Browser disable/enable
  - fast UI profile
- Settings persist and are re-applied when KOReader starts.
- New `docs/PERFORMANCE.md` with device-specific research, trade-offs, measurement
  method, and build notes.
- No kernel, bootloader or NAND changes.

## v0.2.0 — 2026-11-04

- Shim v2: on-demand **USB mass storage**, **ADB**, and **back to stock** modes.
- New KOReader plugin `cybook.koplugin` for those modes.
- Automatic crash safety: two quick KOReader failures create `.disabled` and fall back
  to the stock reader.
- Added read-only `scripts/preflight.sh`; the ADB installer runs it automatically.
- ADB installer copies the plugin.
- Full release zip includes the plugin ready to use.
- Adapted from the mode-switching design and plugin in
  [bruthethe/saraiva-lev-koreader](https://github.com/bruthethe/saraiva-lev-koreader).
- The Lev PWM minimum-frontlight tweak is intentionally **not** ported: it writes a
  hardware register and is specific to that panel/frontlight revision.

## v0.1.0 — 2026-11-01

- Initial public release.
- Tested on Cybook Odyssey HD FrontLight 2 (`CYBOY5F`), firmware build 11.
- KOReader boot shim at `/mnt/app/boordr`; stock reader preserved as
  `/mnt/app/boordr.stock`.
- Stops `cyevd` before KOReader and restarts it for the stock fallback.
- No-ADB install via the `cybook_upgrade` hook.
- ADB install/update/uninstall scripts.
- `.disabled` marker for booting the stock reader.
- microSD recovery scripts for disabling KOReader or restoring stock.
