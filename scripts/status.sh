#!/bin/sh

set -eu
# shellcheck source=common.sh
. "$(dirname -- "$0")/common.sh"

INSTANCE_NAME=${1:-p5-lab-01}
validate_instance_name "$INSTANCE_NAME"

"$CONTAINER_BIN" inspect "$INSTANCE_NAME"
if "$CONTAINER_BIN" exec "$INSTANCE_NAME" /usr/bin/true >/dev/null 2>&1; then
    echo "P5 version:"
    "$CONTAINER_BIN" exec "$INSTANCE_NAME" \
        /usr/local/aw/bin/nsdchat -c srvinfo lexxvers
    echo "Filesystems:"
    "$CONTAINER_BIN" exec "$INSTANCE_NAME" \
        /bin/df -h / /usr/local/aw /host_dir
    echo "Resource use:"
    "$CONTAINER_BIN" stats --no-stream "$INSTANCE_NAME"
fi

