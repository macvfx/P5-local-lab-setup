#!/bin/sh

set -eu
# shellcheck source=versions-common.sh
. "$(dirname -- "$0")/versions-common.sh"

VERSION=${1:?"Usage: $0 <version> <url> [image-tag]"}
URL=${2:?"Usage: $0 <version> <url> [image-tag]"}
IMAGE_TAG=${3:-"p5-lab:$VERSION"}

validate_p5_version "$VERSION"

VERSION_FILE="$P5_VERSIONS_DIR/$VERSION.env"
if [ -f "$VERSION_FILE" ]; then
    echo "versions/$VERSION.env already exists; refusing to overwrite a pinned version." >&2
    echo "Delete it first if you intend to re-pin $VERSION from a different URL." >&2
    exit 1
fi

WORK_DIR="$P5_LAB_ROOT/vendor/custom-$VERSION"
if [ -e "$WORK_DIR" ]; then
    echo "$WORK_DIR already exists; remove it before retrying." >&2
    exit 1
fi
mkdir -p "$WORK_DIR"

FILENAME=$(basename "$URL" | sed 's/[?#].*//')
if [ -z "$FILENAME" ]; then
    echo "Could not derive a filename from $URL." >&2
    exit 1
fi
DOWNLOADED="$WORK_DIR/$FILENAME"

echo "Downloading $URL"
echo "Note: for a custom or historical major-version URL, Archiware's own"
echo "retention of this exact link is not guaranteed. Pin it now; do not"
echo "assume it will still resolve later."
if ! curl --fail --location --show-error --output "$DOWNLOADED" "$URL"; then
    echo "Download failed. If this is the download page's human-facing link" >&2
    echo "(?awdl=...), it may reject a plain curl client (seen before with" >&2
    echo "the current pin); try resolving the real file URL in a browser and" >&2
    echo "pass that URL instead." >&2
    rm -rf "$WORK_DIR"
    exit 1
fi

case "$FILENAME" in
    *.zip)
        echo "Extracting $FILENAME to find the container root filesystem tar."
        if ! command -v unzip >/dev/null 2>&1; then
            echo "unzip was not found; install it and re-run." >&2
            exit 1
        fi
        unzip -o "$DOWNLOADED" -d "$WORK_DIR" >/dev/null
        TAR_COUNT=$(find "$WORK_DIR" -maxdepth 1 -name '*.tar' | wc -l | tr -d ' ')
        if [ "$TAR_COUNT" -ne 1 ]; then
            echo "Expected exactly one .tar file after extracting $FILENAME; found $TAR_COUNT." >&2
            echo "Inspect $WORK_DIR manually and re-run once a single .tar remains there." >&2
            exit 1
        fi
        TAR_PATH=$(find "$WORK_DIR" -maxdepth 1 -name '*.tar')
        ;;
    *.tar)
        TAR_PATH="$DOWNLOADED"
        ;;
    *)
        echo "Unrecognized file type for $FILENAME; expected a .zip or .tar download." >&2
        exit 1
        ;;
esac

if stat -f '%z' "$TAR_PATH" >/dev/null 2>&1; then
    SIZE=$(stat -f '%z' "$TAR_PATH")
else
    SIZE=$(stat -c '%s' "$TAR_PATH")
fi

if command -v shasum >/dev/null 2>&1; then
    SHA256=$(shasum -a 256 "$TAR_PATH" | awk '{ print $1 }')
else
    SHA256=$(sha256sum "$TAR_PATH" | awk '{ print $1 }')
fi

TAR_FILENAME=$(basename "$TAR_PATH")
FINAL_TAR="$P5_LAB_ROOT/vendor/$TAR_FILENAME"
if [ -f "$FINAL_TAR" ]; then
    echo "vendor/$TAR_FILENAME already exists from a different pinned version." >&2
    echo "Rename the incoming file or the existing one before continuing." >&2
    exit 1
fi
mv "$TAR_PATH" "$FINAL_TAR"
rm -rf "$WORK_DIR"

mkdir -p "$P5_VERSIONS_DIR"
cat > "$VERSION_FILE" <<EOF
# Pinned by scripts/add-p5-version.sh on $(date -u +%Y-%m-%dT%H:%M:%SZ).
# P5_EXPECTED_SHA256 below is an OBSERVED value computed from this one
# download, not a vendor-published checksum. If Archiware publishes an
# official checksum for this version, verify against it separately and
# note that in this file.
P5_VERSION="$VERSION"
P5_SOURCE_URL="$URL"
P5_VENDOR_TAR_FILENAME="$TAR_FILENAME"
P5_EXPECTED_SIZE="$SIZE"
P5_EXPECTED_SHA256="$SHA256"
P5_IMAGE_TAG="$IMAGE_TAG"
EOF

echo
echo "Pinned $VERSION as $IMAGE_TAG."
echo "Vendor tar: vendor/$TAR_FILENAME ($SIZE bytes, sha256 $SHA256)"
echo "Registry entry: versions/$VERSION.env"
echo
echo "This did not change versions/CURRENT. Build and use it explicitly:"
echo "  ./scripts/build-image.sh $VERSION"
echo "  ./scripts/create-instance.sh <name> <rest-port> <cli-port> $VERSION"
