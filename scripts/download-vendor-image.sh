#!/bin/sh

set -eu

P5_LAB_ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)

VENDOR_DIR="$P5_LAB_ROOT/vendor"
DESTINATION="$VENDOR_DIR/awpst806-container.tar"
PARTIAL="$DESTINATION.partial"
SOURCE_URL="https://p5-downloads.s3.amazonaws.com/awpst806-container.tar"
DOWNLOAD_PAGE="https://www.archiware.com/download-p5/"
VENDOR_PACKAGE_URL="https://www.archiware.com/?awdl=Linux_Docker_awspst806.zip&awpf=synology"
EXPECTED_SIZE="362757632"
EXPECTED_MD5="04255bb0decabeb9571b6f8a96911da8"

mkdir -p "$VENDOR_DIR"

if [ -f "$DESTINATION" ]; then
    echo "Vendor image already exists; verifying it."
else
    if [ -e "$PARTIAL" ]; then
        echo "A partial download already exists at $PARTIAL; remove it before retrying." >&2
        exit 1
    fi
    echo "Official P5 download page: $DOWNLOAD_PAGE"
    echo "Tested Linux Docker package page: $VENDOR_PACKAGE_URL"
    echo "Downloading the pinned Archiware P5 8.0.6 container root filesystem:"
    echo "$SOURCE_URL"
    echo "Download size is about 346 MiB."
    curl --fail --location --show-error --output "$PARTIAL" "$SOURCE_URL"
    mv "$PARTIAL" "$DESTINATION"
fi

if stat -f '%z' "$DESTINATION" >/dev/null 2>&1; then
    ACTUAL_SIZE=$(stat -f '%z' "$DESTINATION")
else
    ACTUAL_SIZE=$(stat -c '%s' "$DESTINATION")
fi

if command -v md5 >/dev/null 2>&1; then
    ACTUAL_MD5=$(md5 -q "$DESTINATION")
else
    ACTUAL_MD5=$(md5sum "$DESTINATION" | awk '{ print $1 }')
fi

if [ "$ACTUAL_SIZE" != "$EXPECTED_SIZE" ]; then
    echo "Unexpected file size: $ACTUAL_SIZE bytes; expected $EXPECTED_SIZE." >&2
    exit 1
fi
if [ "$ACTUAL_MD5" != "$EXPECTED_MD5" ]; then
    echo "Unexpected MD5: $ACTUAL_MD5; expected $EXPECTED_MD5." >&2
    exit 1
fi

echo "Vendor image verified: $ACTUAL_SIZE bytes, MD5 $ACTUAL_MD5"
if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$DESTINATION"
else
    sha256sum "$DESTINATION"
fi

