#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Build KOReader's "bookeen" target in the official Docker image.

set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OUT_DIR="${OUT_DIR:-$REPO_ROOT/dist}"
SRC="${KOREADER_SRC:-/tmp/cybook-koreader-build/koreader}"
COMMIT="${KOREADER_COMMIT:-035e00b21d0286325ef2e8a7e3b6326f340e2ded}"
IMAGE="${KOREADER_DOCKER_IMAGE:-koreader/kobookeen:latest}"

die() { echo "error: $*" >&2; exit 1; }

command -v docker >/dev/null 2>&1 || die "docker not found"
docker info >/dev/null 2>&1 || die "Docker daemon is not running"
command -v git >/dev/null 2>&1 || die "git not found"

mkdir -p "$OUT_DIR" "$(dirname "$SRC")"

if [ ! -d "$SRC/.git" ]; then
    echo "==> Cloning KOReader"
    git clone --recurse-submodules https://github.com/koreader/koreader.git "$SRC"
fi

echo "==> Checking out $COMMIT"
if [ "$(git -C "$SRC" rev-parse --is-shallow-repository 2>/dev/null || echo false)" = "true" ]; then
    git -C "$SRC" fetch --unshallow --tags --force origin
else
    git -C "$SRC" fetch --tags --force origin
fi
git -C "$SRC" checkout --force "$COMMIT"

# Only the top-level submodules and crengine are needed for the Bookeen build.
# A recursive update tries to fetch nested test/third-party submodules whose
# pinned commits are sometimes not advertised by their upstream remotes.
git -C "$SRC" submodule update --init
git -C "$SRC/base" submodule update --init thirdparty/kpvcrlib/crengine || true

# Some networks block download.gnome.org. Pre-seed the exact tarball that this
# KOReader commit expects. The build itself remains fully reproducible.
GLIB="$SRC/base/thirdparty/glib/build/downloads/glib-2.82.1.tar.xz"
GLIB_MD5="d101f1acab6805d4d6d3104e9634b8e3"
GLIB_URL="${GLIB_URL:-https://mirrors.dotsrc.org/gnome/sources/glib/2.82/glib-2.82.1.tar.xz}"

md5_of() {
    if command -v md5sum >/dev/null 2>&1; then
        md5sum "$1" | awk '{print $1}'
    elif command -v md5 >/dev/null 2>&1; then
        md5 -q "$1"
    else
        echo ""
    fi
}

if [ ! -f "$GLIB" ]; then
    echo "==> Pre-fetching glib tarball from $GLIB_URL"
    mkdir -p "$(dirname "$GLIB")"
    if curl -fL --retry 3 --max-time 180 -o "$GLIB.part" "$GLIB_URL"; then
        mv "$GLIB.part" "$GLIB"
    else
        rm -f "$GLIB.part"
        echo "warning: could not pre-fetch glib; the build may fail if download.gnome.org is blocked" >&2
    fi
fi

if [ -f "$GLIB" ]; then
    got=$(md5_of "$GLIB")
    if [ -n "$got" ] && [ "$got" != "$GLIB_MD5" ]; then
        echo "warning: glib MD5 mismatch ($got); removing cached file" >&2
        rm -f "$GLIB"
    fi
fi

echo "==> Docker image: $IMAGE"
docker image inspect "$IMAGE" >/dev/null 2>&1 || docker pull "$IMAGE"

echo "==> Building KOReader (bookeen target)"
docker run --rm \
    --user "$(id -u):$(id -g)" \
    -e HOME=/tmp \
    -v "$SRC:$SRC" \
    -w "$SRC" \
    "$IMAGE" \
    bash -lc './kodev release --ignore-translation bookeen'

ZIP=$(ls -t "$SRC"/koreader-bookeen-*.zip 2>/dev/null | head -n 1 || true)
[ -n "$ZIP" ] || die "build finished but no koreader-bookeen-*.zip was produced"

cp -f "$ZIP" "$OUT_DIR/"
echo "==> Built: $OUT_DIR/$(basename "$ZIP")"
if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$OUT_DIR/$(basename "$ZIP")"
else
    shasum -a 256 "$OUT_DIR/$(basename "$ZIP")"
fi
