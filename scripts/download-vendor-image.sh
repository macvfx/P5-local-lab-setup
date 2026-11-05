#!/bin/sh

set -eu
# shellcheck source=common.sh
. "$(dirname -- "$0")/common.sh"

VENDOR_DIR="$P5_LAB_ROOT/vendor"
DESTINATION="$VENDOR_DIR/awpst806-container.tar"
PARTIAL="$DESTINATION.partial"
SOURCE_URL="https://p5-downloads.s3.amazonaws.com/awpst806-container.tar"
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
    echo "Downloading Archiware P5 8.0.6 container root filesystem (about 346 MiB)."
    curl --fail --location --show-error --output "$PARTIAL" "$SOURCE_URL"
    mv "$PARTIAL" "$DESTINATION"
fi

ACTUAL_SIZE=$(stat -f '%z' "$DESTINATION")
ACTUAL_MD5=$(md5 -q "$DESTINATION")

if [ "$ACTUAL_SIZE" != "$EXPECTED_SIZE" ]; then
    echo "Unexpected file size: $ACTUAL_SIZE bytes; expected $EXPECTED_SIZE." >&2
    exit 1
fi
if [ "$ACTUAL_MD5" != "$EXPECTED_MD5" ]; then
    echo "Unexpected MD5: $ACTUAL_MD5; expected $EXPECTED_MD5." >&2
    exit 1
fi

echo "Vendor image verified: $ACTUAL_SIZE bytes, MD5 $ACTUAL_MD5"
shasum -a 256 "$DESTINATION"

