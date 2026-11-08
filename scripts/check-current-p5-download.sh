#!/bin/sh

set -eu
# shellcheck source=versions-common.sh
. "$(dirname -- "$0")/versions-common.sh"

DOWNLOAD_PAGE="https://www.archiware.com/download-p5/"

resolve_p5_version "${1:-}"
PINNED_VERSION="$P5_VERSION"
PINNED_PACKAGE="${P5_PACKAGE_FILENAME:-}"

PAGE=$(curl --fail --silent --show-error --location "$DOWNLOAD_PAGE")

CURRENT_VERSION=$(printf '%s\n' "$PAGE" | sed -n \
    's/.*Archiware P5 Version \([0-9][0-9.]*\).*/\1/p' | head -n 1)
CURRENT_PACKAGE=$(printf '%s\n' "$PAGE" | sed -n \
    's/.*href="\/?awdl=\(Linux_Docker_awspst[0-9][0-9]*\.zip\)&#038;awpf=synology".*/\1/p' | head -n 1)

if [ -z "$CURRENT_VERSION" ] || [ -z "$CURRENT_PACKAGE" ]; then
    echo "Could not find the current P5 version and Linux Docker download on:" >&2
    echo "$DOWNLOAD_PAGE" >&2
    echo "Archiware may have changed the page; inspect it manually before updating." >&2
    exit 1
fi

CURRENT_URL="https://www.archiware.com/?awdl=$CURRENT_PACKAGE&awpf=synology"

echo "Official P5 download page: $DOWNLOAD_PAGE"
echo "Current P5 release shown there: $CURRENT_VERSION"
echo "Current Linux Docker package: $CURRENT_URL"
echo "Pinned lab version checked: $PINNED_VERSION"
if [ -n "$PINNED_PACKAGE" ]; then
    echo "Pinned vendor package: https://www.archiware.com/?awdl=$PINNED_PACKAGE&awpf=synology"
fi

if [ "$CURRENT_VERSION" = "$PINNED_VERSION" ] && \
   { [ -z "$PINNED_PACKAGE" ] || [ "$CURRENT_PACKAGE" = "$PINNED_PACKAGE" ]; }; then
    echo "Status: the current vendor download matches versions/$PINNED_VERSION.env."
else
    echo "Status: Archiware now advertises a different release than versions/$PINNED_VERSION.env."
    echo "Do not silently substitute it. Pin the new release with:"
    echo "  ./scripts/add-p5-version.sh $CURRENT_VERSION $CURRENT_URL"
    echo "Keep this pin (versions/$PINNED_VERSION.env) and its built image around"
    echo "for regression testing; only update versions/CURRENT once the new"
    echo "pin is downloaded, verified, and built."
fi
