#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Build all release assets: installer zip, KOReader zip, and source tarball.

set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OUT_DIR="${OUT_DIR:-$REPO_ROOT/dist}"

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

"$REPO_ROOT/scripts/make-dist.sh"
"$REPO_ROOT/scripts/build-koreader.sh"
"$REPO_ROOT/scripts/make-full.sh"
"$REPO_ROOT/scripts/make-source.sh"

echo "==> Writing checksums"
(
    cd "$OUT_DIR"
    if command -v sha256sum >/dev/null 2>&1; then
        : > SHA256SUMS
        for f in *; do
            [ -f "$f" ] || continue
            if [ "$f" = "SHA256SUMS" ]; then
                continue
            fi
            sha256sum "$f" >> SHA256SUMS
        done
    else
        : > SHA256SUMS
        for f in *; do
            [ -f "$f" ] || continue
            if [ "$f" = "SHA256SUMS" ]; then
                continue
            fi
            shasum -a 256 "$f" >> SHA256SUMS
        done
    fi
)

echo "==> Release assets in $OUT_DIR"
ls -lh "$OUT_DIR"
