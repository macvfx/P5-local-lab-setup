#!/bin/sh

set -eu
# shellcheck source=versions-common.sh
. "$(dirname -- "$0")/versions-common.sh"

CURRENT_VERSION=""
if [ -f "$P5_CURRENT_FILE" ]; then
    CURRENT_VERSION=$(cat "$P5_CURRENT_FILE")
fi

printf '%-10s %-8s %-8s %-30s\n' "VERSION" "CURRENT" "TAR" "IMAGE"
for ENTRY in "$P5_VERSIONS_DIR"/*.env; do
    [ -f "$ENTRY" ] || continue
    VERSION=$(basename "$ENTRY" .env)

    IS_CURRENT="no"
    [ "$VERSION" = "$CURRENT_VERSION" ] && IS_CURRENT="yes"

    # shellcheck disable=SC1090
    . "$ENTRY"
    TAR_STATUS="missing"
    [ -f "$P5_LAB_ROOT/vendor/$P5_VENDOR_TAR_FILENAME" ] && TAR_STATUS="present"

    printf '%-10s %-8s %-8s %-30s\n' "$VERSION" "$IS_CURRENT" "$TAR_STATUS" "$P5_IMAGE_TAG"
done
