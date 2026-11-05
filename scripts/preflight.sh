#!/bin/sh

set -eu
# shellcheck source=common.sh
. "$(dirname -- "$0")/common.sh"

echo "P5 Local Lab preflight"
echo "Container CLI: $CONTAINER_BIN"
"$CONTAINER_BIN" --version

if [ "$(uname -m)" != "arm64" ]; then
    echo "This workflow currently targets Apple silicon Macs." >&2
    exit 1
fi

MACOS_MAJOR=$(sw_vers -productVersion | cut -d. -f1)
if [ "$MACOS_MAJOR" -lt 26 ]; then
    echo "macOS 26 or later is required by Apple's container runtime." >&2
    exit 1
fi

STATUS=$("$CONTAINER_BIN" system status)
printf '%s\n' "$STATUS"

CLIENT_VERSION=$(printf '%s\n' "$STATUS" | awk '$1 == "client.version" { print $2 }')
SERVER_VERSION=$(printf '%s\n' "$STATUS" | awk '$1 == "server.version" { print $2 }')
if [ -z "$CLIENT_VERSION" ] || [ -z "$SERVER_VERSION" ]; then
    echo "Could not determine container client and server versions." >&2
    exit 1
fi
if [ "$CLIENT_VERSION" != "$SERVER_VERSION" ]; then
    echo "Container client $CLIENT_VERSION and server $SERVER_VERSION do not match." >&2
    exit 1
fi

echo "Preflight passed. Client and server both report $CLIENT_VERSION."

