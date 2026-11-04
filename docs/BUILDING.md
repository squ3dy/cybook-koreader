# Building

## Requirements

- Docker (Docker Desktop on macOS, Docker Engine on Linux)
- `git`, `curl`, `tar`, `unzip`, `zip`
- About 5–10 GB free disk space
- 20–60 minutes depending on CPU and cache

The build uses the official KOReader Bookeen Docker image:

```
koreader/kobookeen:latest
```

It contains the `arm-bookeen-linux-gnueabi` cross toolchain and the target sysroot.

## Build just KOReader

```sh
./scripts/build-koreader.sh
```

By default this:

1. Clones KOReader into `/tmp/cybook-koreader-build/koreader` (full clone, so version
   tags work). A neutral build path is used deliberately: compiled-in paths then contain
   `/tmp`, not your home directory/username.
2. Checks out the pinned commit:
   `035e00b21d0286325ef2e8a7e3b6326f340e2ded`
3. Updates submodules.
4. Pre-fetches `glib-2.82.1.tar.xz` from a mirror that is not blocked on some networks.
5. Runs `./kodev release --ignore-translation bookeen` inside
   `koreader/kobookeen:latest`. Ignoring the translation refresh keeps the pinned
   `l10n` submodule, so the binary and the source tarball match.
6. Copies the resulting `koreader-bookeen-*.zip` to `dist/`.

Environment overrides:

```sh
KOREADER_COMMIT=<sha>        # build another commit
KOREADER_SRC=/path/to/src    # reuse an existing checkout (use a neutral path!)
KOREADER_DOCKER_IMAGE=...    # use a different image
OUT_DIR=/path/to/dist        # output directory
GLIB_URL=...                 # alternate glib tarball URL
```

## The `download.gnome.org` problem

On some networks the build fails while downloading:

```
https://download.gnome.org/sources/glib/2.82/glib-2.82.1.tar.xz
Connection refused
```

The script pre-fetches the exact file from:

```
https://mirrors.dotsrc.org/gnome/sources/glib/2.82/glib-2.82.1.tar.xz
```

Expected MD5:

```
d101f1acab6805d4d6d3104e9634b8e3
```

If your network blocks that mirror too, download the same file elsewhere and place it
here before building:

```
/tmp/cybook-koreader-build/koreader/base/thirdparty/glib/build/downloads/glib-2.82.1.tar.xz
```

## Build all release assets

```sh
./scripts/make-release.sh
```

This creates:

```
dist/koreader-bookeen-*.zip
dist/cybook-koreader-installer-<version>.zip
dist/cybook-koreader-full-<version>.zip
dist/koreader-source-*.tar.gz
dist/SHA256SUMS
```

The source tarball is created from the exact KOReader checkout. Keep it with the
binary release for AGPL compliance, or link to the exact upstream commit and
submodules in `SOURCE.md`.

## Installer only

```sh
./scripts/make-dist.sh
```

This creates the small installer/documentation zip. It does not build KOReader.

## GitHub Actions

`.github/workflows/release.yml` builds everything on a tag. This repository already has
the local tag `v0.3.0`; push it:

```sh
git push origin v0.3.0
```

For a later release, create a new tag first.

The workflow uses Docker on `ubuntu-latest`, runs `scripts/make-release.sh`, and
uploads `dist/*` to a GitHub Release using `gh release create`.

## Reproducibility

The KOReader commit and Docker image digest are recorded in `SOURCE.md`. The build is
deterministic enough for packaging, but upstream third-party tarballs and the Docker
image tag can change. For a long-term reproducible build, pin the image by digest and
archive the source tarball from the release.
