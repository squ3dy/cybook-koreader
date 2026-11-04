#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Build the one-file "extract to the reader root" release.

set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OUT_DIR="${OUT_DIR:-$REPO_ROOT/dist}"
VERSION=$(cat "$REPO_ROOT/VERSION")
KO_ZIP="${KO_ZIP:-$(ls -t "$OUT_DIR"/koreader-bookeen-*.zip 2>/dev/null | head -n 1 || true)}"

die() { echo "error: $*" >&2; exit 1; }

[ -n "$KO_ZIP" ] || die "no koreader-bookeen-*.zip in $OUT_DIR; run build-koreader.sh first"
[ -f "$KO_ZIP" ] || die "KOReader zip not found: $KO_ZIP"

STAGE=$(mktemp -d "${TMPDIR:-/tmp}/cybook-full.XXXXXX")
cleanup() { rm -rf "$STAGE"; }
trap cleanup EXIT INT TERM

unzip -q "$KO_ZIP" -d "$STAGE"
[ -f "$STAGE/koreader/koreader.sh" ] || die "KOReader zip has no koreader/koreader.sh"

mkdir -p "$STAGE/koreader/plugins"
cp -R "$REPO_ROOT/plugin/cybook.koplugin" "$STAGE/koreader/plugins/"

cp "$REPO_ROOT/README.md" "$STAGE/"
cp "$REPO_ROOT/LICENSE" "$STAGE/"
cp "$REPO_ROOT/CREDITS.md" "$STAGE/"
cp "$REPO_ROOT/SOURCE.md" "$STAGE/"
cp "$REPO_ROOT/CHANGELOG.md" "$STAGE/"
cp "$REPO_ROOT/VERSION" "$STAGE/"
cp "$REPO_ROOT/installer/cybook_upgrade" "$STAGE/"
cp -R "$REPO_ROOT/docs" "$STAGE/"
cp -R "$REPO_ROOT/recovery" "$STAGE/"
cp -R "$REPO_ROOT/scripts" "$STAGE/"

OUT="$OUT_DIR/cybook-koreader-full-$VERSION.zip"
rm -f "$OUT"
( cd "$STAGE" && zip -q -r "$OUT" . )

echo "==> Built: $OUT"
