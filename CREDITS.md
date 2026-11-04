# Credits

This project is a thin integration layer around other people's work.

## KOReader

- [KOReader](https://github.com/koreader/koreader) — the reader itself.
- The `bookeen` target and the `bookeen` device profile were added by
  **Wesley Guedes (banzai200)** with **rstar000**, **lenaing**, **benoit-pierre**,
  and **Frenzie**.
- The original Bookeen port work was done by **rstar000** and **lenaing**.
- `installer/cybook_upgrade` is derived from
  [`platform/bookeen/cybook_upgrade`](https://github.com/koreader/koreader/blob/master/platform/bookeen/cybook_upgrade)
  in the KOReader repository, licensed AGPL-3.0.

## Bookeen / Cybook research

- **br-lemes** — [lev-jailbreak](https://github.com/br-lemes/lev-jailbreak), SSH/root
  research and the `CybUpdate.bin` packaging details.
- **bruthethe** — [saraiva-lev-koreader](https://github.com/bruthethe/saraiva-lev-koreader):
  the mode-switching `boordr` shim, KOReader plugin, crash safety switch, preflight
  structure, and USB/ADB mode design. The CYBOY5F port adapts those ideas and adds the
  `cyevd` handling.
- **Oitalao** — [Jailbreak-Saraiva-Lev](https://github.com/Oitalao/Jailbreak-Saraiva-Lev),
  practical recovery and install documentation.
- The MobileRead wiki and forum threads documenting the Cybook Odyssey hardware.
- Bookeen, for the device and firmware. This project is not affiliated with or
  endorsed by Bookeen.

## This repository

- Installer/shim modifications for `CYBOY5F` and the `cyevd` input fix:
  the repository contributors.

If you are one of the upstream authors and want a different attribution or link,
please open an issue.
