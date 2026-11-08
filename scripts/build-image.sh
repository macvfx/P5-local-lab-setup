#!/bin/sh

set -eu
# shellcheck source=common.sh
. "$(dirname -- "$0")/common.sh"

"$P5_LAB_ROOT/scripts/preflight.sh"

resolve_p5_version "${1:-}"

VENDOR_IMAGE="$P5_LAB_ROOT/vendor/$P5_VENDOR_TAR_FILENAME"
if [ ! -f "$VENDOR_IMAGE" ]; then
    echo "Run scripts/download-vendor-image.sh $P5_VERSION first." >&2
    exit 1
fi

echo "Building $P5_IMAGE_TAG for linux/amd64."
"$CONTAINER_BIN" build \
    --arch amd64 \
    --tag "$P5_IMAGE_TAG" \
    --build-arg "P5_VENDOR_TAR_FILENAME=$P5_VENDOR_TAR_FILENAME" \
    --build-arg "P5_VERSION=$P5_VERSION" \
    --file "$P5_LAB_ROOT/Dockerfile" \
    "$P5_LAB_ROOT"

"$CONTAINER_BIN" image inspect "$P5_IMAGE_TAG"
