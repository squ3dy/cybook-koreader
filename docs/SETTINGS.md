# Suggested KOReader settings

These are tuned for the A13 / 256 MB / 6" 758×1024 screen, not for a modern tablet.

## Performance

| Setting | Menu | Value |
|---|---|---|
| Full refresh rate | Settings → Screen → E-ink settings | Every 6 pages |
| Use smaller panning rate | Settings → Screen → E-ink settings | On |
| Page turn animations | Settings → Page turns | Off |
| Cover browser | File browser → Cover browser | Off / classic |
| Start with | File browser menu → Start with | Most recent document |
| Auto-update | Settings → Update | Off |
| Unused plugins | Tools → Plugin management | Disable what you do not use |
| Wi-Fi | Network menu | Off while reading |

Cover thumbnails, news downloads, Wallabag, HTTP inspector, and other background
plugins cost RAM and CPU on this device.

## Reading

- Font: **Noto Serif** or **Literata**, 10–11 pt.
- Font weight: +1 if the rendering looks faint.
- Margins: 4–8.
- Line spacing: 105–115%.
- Hyphenation: on for English and Russian.
- Justification: left-aligned, or justified with hyphenation.
- Status bar: page number, percentage, battery, time. Hide title/author to leave more
  room for text.
- Full screen: on.
- Night mode: useful with low frontlight.

## Controls

- Page turns → tap zones: left/right (or top/bottom if you prefer).
- Invert page turn taps and swipes if the direction feels wrong.
- Enable **Use left and right keys for page turning** for the side buttons.
- Keep gestures single-finger; `gt80x` multitouch is not reliable.
- Set long-press to dictionary lookup and tap-top to menu.
- Home button: while reading it opens the Cybook Quick Menu; in menus and dialogs it
  acts as Back one level at a time. In the file manager with no menu open it goes to
  the home folder. Configure it under **Tools → Cybook: Home button**.
- The frontlight dialog uses the side page-turn buttons to lower/raise brightness while
  it is open.

## Power

- Tools → **Auto suspend**: 10–15 minutes suspend, 2–3 days shutdown.
- Tools → **Auto dim**: dim the frontlight after ~60 seconds.
- Screensaver: simple/blank; avoid cover images.
- Test suspend once with a 2-minute timeout before trusting it. If wake is unreliable,
  disable auto-suspend and use power-off.

## PDFs and comics

- Auto crop: on for PDFs with white margins.
- Reflow: on for text-heavy PDFs.
- Landscape/two-page: good for comics and large PDFs.
- For large PDFs, prefer the faster render mode over maximum quality.

## Dictionaries

KOReader uses **StarDict** dictionaries (`.ifo`, `.idx`, `.dict` triplets), not the
stock Bookeen `.dict` files. Put them in the KOReader data directory or point
Settings → Dictionaries to a folder on the FAT partition.

## File transfer

Use the Cybook plugin:

**Tools → Cybook: USB, ADB, stock reader → USB mode**

KOReader closes and exposes the FAT partition as a USB drive. Copy books, eject from
the PC, and unplug; KOReader returns. Do not unplug without ejecting.

As a fallback, create `/mnt/fat/koreader/.disabled` via the Terminal plugin, reboot to
the stock reader, copy books, then delete `.disabled` and reboot.

See [PLUGIN.md](PLUGIN.md).

## Advanced

- **Terminal plugin:** useful for maintenance and recovery.
- **OPDS / Calibre:** works over Wi-Fi if the network stack is stable on your unit.
- **KOSync:** progress sync between devices.
- **Statistics:** optional; it writes more data to the FAT partition.
