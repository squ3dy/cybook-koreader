#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Create a corresponding-source tarball for the KOReader build.

set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OUT_DIR="${OUT_DIR:-$REPO_ROOT/dist}"
SRC="${KOREADER_SRC:-/tmp/cybook-koreader-build/koreader}"

die() { echo "error: $*" >&2; exit 1; }

[ -d "$SRC/.git" ] || die "KOReader source not found at $SRC; run build-koreader.sh first"
mkdir -p "$OUT_DIR"

VERSION=$(git -C "$SRC" describe --tags --match 'v*' --always 2>/dev/null || git -C "$SRC" rev-parse --short HEAD)
OUT="$OUT_DIR/koreader-source-$VERSION.tar.gz"

echo "==> Creating source tarball (this can take a minute)"
tar -C "$SRC" \
    --exclude='.git' \
    --exclude='base/build' \
    --exclude='build' \
    --exclude='*/build' \
    --exclude='*.zip' \
    --exclude='*.tar.gz' \
    --exclude='*.tar.xz' \
    -czf "$OUT" .

echo "==> Built: $OUT"
if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$OUT"
else
    shasum -a 256 "$OUT"
fi
