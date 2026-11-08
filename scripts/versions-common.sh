#!/bin/sh

set -eu

# shellcheck disable=SC2034
P5_LAB_ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
# shellcheck disable=SC2034
P5_VERSIONS_DIR="$P5_LAB_ROOT/versions"
# shellcheck disable=SC2034
P5_CURRENT_FILE="$P5_VERSIONS_DIR/CURRENT"

validate_p5_version() {
    case "$1" in
        ""|*[!0-9A-Za-z.-]*)
            echo "Version must contain only letters, numbers, dots, and hyphens." >&2
            exit 2
            ;;
    esac
}

# Sets P5_VERSION, P5_SOURCE_URL, P5_VENDOR_TAR_FILENAME, P5_IMAGE_TAG, and
# whichever of P5_EXPECTED_SIZE / P5_EXPECTED_MD5 / P5_EXPECTED_SHA256 the
# pinned version file declares. Pass a version, or leave it empty to use
# versions/CURRENT.
resolve_p5_version() {
    REQUESTED_VERSION=${1:-}
    if [ -z "$REQUESTED_VERSION" ]; then
        if [ ! -f "$P5_CURRENT_FILE" ]; then
            echo "$P5_CURRENT_FILE does not exist; pass a version explicitly or create it." >&2
            exit 1
        fi
        REQUESTED_VERSION=$(cat "$P5_CURRENT_FILE")
    fi
    validate_p5_version "$REQUESTED_VERSION"

    P5_VERSION_FILE="$P5_VERSIONS_DIR/$REQUESTED_VERSION.env"
    if [ ! -f "$P5_VERSION_FILE" ]; then
        echo "No pinned version file at versions/$REQUESTED_VERSION.env." >&2
        echo "Run scripts/add-p5-version.sh to pin it first." >&2
        exit 1
    fi

    # shellcheck disable=SC1090
    . "$P5_VERSION_FILE"

    if [ "$P5_VERSION" != "$REQUESTED_VERSION" ]; then
        echo "versions/$REQUESTED_VERSION.env declares P5_VERSION=$P5_VERSION, which does not match its filename ($REQUESTED_VERSION.env)." >&2
        exit 1
    fi
}
