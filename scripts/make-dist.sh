#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Build the small installer/documentation zip.

set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OUT_DIR="${OUT_DIR:-$REPO_ROOT/dist}"
VERSION=$(cat "$REPO_ROOT/VERSION")
OUT="$OUT_DIR/cybook-koreader-installer-$VERSION.zip"
STAGE=$(mktemp -d "${TMPDIR:-/tmp}/cybook-dist.XXXXXX")
cleanup() { rm -rf "$STAGE"; }
trap cleanup EXIT INT TERM

mkdir -p "$OUT_DIR" "$STAGE/docs" "$STAGE/recovery" "$STAGE/scripts"

cp "$REPO_ROOT/README.md" "$STAGE/"
cp "$REPO_ROOT/LICENSE" "$STAGE/"
cp "$REPO_ROOT/CREDITS.md" "$STAGE/"
cp "$REPO_ROOT/SOURCE.md" "$STAGE/"
cp "$REPO_ROOT/CHANGELOG.md" "$STAGE/"
cp "$REPO_ROOT/VERSION" "$STAGE/"
cp "$REPO_ROOT/installer/cybook_upgrade" "$STAGE/"
cp -R "$REPO_ROOT/plugin" "$STAGE/plugin"
cp "$REPO_ROOT"/docs/*.md "$STAGE/docs/"
cp "$REPO_ROOT"/recovery/* "$STAGE/recovery/"
cp "$REPO_ROOT"/scripts/*.sh "$STAGE/scripts/"

rm -f "$OUT"
( cd "$STAGE" && zip -q -r "$OUT" . )

echo "==> Built: $OUT"
