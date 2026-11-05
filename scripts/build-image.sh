#!/bin/sh

set -eu
# shellcheck source=common.sh
. "$(dirname -- "$0")/common.sh"

"$P5_LAB_ROOT/scripts/preflight.sh"

VENDOR_IMAGE="$P5_LAB_ROOT/vendor/awpst806-container.tar"
if [ ! -f "$VENDOR_IMAGE" ]; then
    echo "Run scripts/download-vendor-image.sh first." >&2
    exit 1
fi

echo "Building $P5_IMAGE_TAG for linux/amd64."
"$CONTAINER_BIN" build \
    --arch amd64 \
    --tag "$P5_IMAGE_TAG" \
    --file "$P5_LAB_ROOT/Dockerfile" \
    "$P5_LAB_ROOT"

"$CONTAINER_BIN" image inspect "$P5_IMAGE_TAG"

