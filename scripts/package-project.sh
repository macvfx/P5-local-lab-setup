#!/bin/sh

set -eu

P5_LAB_ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
VERSION=$(tr -d '[:space:]' < "$P5_LAB_ROOT/VERSION")
DIST_DIR="$P5_LAB_ROOT/dist"
ARCHIVE="$DIST_DIR/P5-Local-Lab-$VERSION.zip"

if ! git -C "$P5_LAB_ROOT" diff --quiet || \
   ! git -C "$P5_LAB_ROOT" diff --cached --quiet; then
    echo "Commit or stash project changes before packaging." >&2
    exit 1
fi

mkdir -p "$DIST_DIR"
git -C "$P5_LAB_ROOT" archive \
    --format=zip \
    --prefix="P5-Local-Lab-$VERSION/" \
    --output="$ARCHIVE" \
    HEAD

shasum -a 256 "$ARCHIVE" > "$ARCHIVE.sha256"
echo "Created $ARCHIVE"
cat "$ARCHIVE.sha256"
