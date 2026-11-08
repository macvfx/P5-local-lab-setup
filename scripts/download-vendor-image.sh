#!/bin/sh

set -eu
# shellcheck source=versions-common.sh
. "$(dirname -- "$0")/versions-common.sh"

resolve_p5_version "${1:-}"

VENDOR_DIR="$P5_LAB_ROOT/vendor"
DESTINATION="$VENDOR_DIR/$P5_VENDOR_TAR_FILENAME"
PARTIAL="$DESTINATION.partial"

mkdir -p "$VENDOR_DIR"

if [ -f "$DESTINATION" ]; then
    echo "Vendor image for $P5_VERSION already exists; verifying it."
else
    if [ -e "$PARTIAL" ]; then
        echo "A partial download already exists at $PARTIAL; remove it before retrying." >&2
        exit 1
    fi
    echo "Downloading the pinned P5 $P5_VERSION container root filesystem:"
    echo "$P5_SOURCE_URL"
    curl --fail --location --show-error --output "$PARTIAL" "$P5_SOURCE_URL"
    mv "$PARTIAL" "$DESTINATION"
fi

if stat -f '%z' "$DESTINATION" >/dev/null 2>&1; then
    ACTUAL_SIZE=$(stat -f '%z' "$DESTINATION")
else
    ACTUAL_SIZE=$(stat -c '%s' "$DESTINATION")
fi

if [ -n "${P5_EXPECTED_SIZE:-}" ] && [ "$ACTUAL_SIZE" != "$P5_EXPECTED_SIZE" ]; then
    echo "Unexpected file size: $ACTUAL_SIZE bytes; expected $P5_EXPECTED_SIZE." >&2
    exit 1
fi

VERIFIED_SOMETHING=0

if [ -n "${P5_EXPECTED_MD5:-}" ]; then
    if command -v md5 >/dev/null 2>&1; then
        ACTUAL_MD5=$(md5 -q "$DESTINATION")
    else
        ACTUAL_MD5=$(md5sum "$DESTINATION" | awk '{ print $1 }')
    fi
    if [ "$ACTUAL_MD5" != "$P5_EXPECTED_MD5" ]; then
        echo "Unexpected MD5: $ACTUAL_MD5; expected $P5_EXPECTED_MD5." >&2
        exit 1
    fi
    VERIFIED_SOMETHING=1
fi

if [ -n "${P5_EXPECTED_SHA256:-}" ]; then
    if command -v shasum >/dev/null 2>&1; then
        ACTUAL_SHA256=$(shasum -a 256 "$DESTINATION" | awk '{ print $1 }')
    else
        ACTUAL_SHA256=$(sha256sum "$DESTINATION" | awk '{ print $1 }')
    fi
    if [ "$ACTUAL_SHA256" != "$P5_EXPECTED_SHA256" ]; then
        echo "Unexpected SHA-256: $ACTUAL_SHA256; expected $P5_EXPECTED_SHA256." >&2
        exit 1
    fi
    VERIFIED_SOMETHING=1
fi

if [ "$VERIFIED_SOMETHING" -eq 0 ]; then
    echo "versions/$P5_VERSION.env declares no P5_EXPECTED_MD5 or P5_EXPECTED_SHA256; refusing to accept an unverifiable download." >&2
    exit 1
fi

echo "Vendor image for $P5_VERSION verified: $ACTUAL_SIZE bytes."
