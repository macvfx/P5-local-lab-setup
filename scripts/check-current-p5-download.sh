#!/bin/sh

set -eu

DOWNLOAD_PAGE="https://www.archiware.com/download-p5/"
PINNED_VERSION="8.0.6"
PINNED_PACKAGE="Linux_Docker_awspst806.zip"

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
echo "Tested lab version: $PINNED_VERSION"
echo "Tested vendor package: https://www.archiware.com/?awdl=$PINNED_PACKAGE&awpf=synology"

if [ "$CURRENT_VERSION" = "$PINNED_VERSION" ] && \
   [ "$CURRENT_PACKAGE" = "$PINNED_PACKAGE" ]; then
    echo "Status: the current vendor download matches this lab's tested pin."
else
    echo "Status: Archiware offers a different release than this lab's tested pin."
    echo "Do not silently substitute it. Update the pin, digest, image tag, docs, and acceptance evidence together."
fi
