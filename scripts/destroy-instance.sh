#!/bin/sh

set -eu
# shellcheck source=common.sh
. "$(dirname -- "$0")/common.sh"

INSTANCE_NAME=${1:-}
CONFIRMATION=${2:-}
validate_instance_name "$INSTANCE_NAME"

if [ "$CONFIRMATION" != "--confirm" ]; then
    echo "Usage: $0 <instance-name> --confirm" >&2
    echo "This deletes the container's writable P5 configuration layer." >&2
    echo "The bind-mounted instance folder is preserved." >&2
    exit 2
fi

if ! INSPECTION=$("$CONTAINER_BIN" inspect "$INSTANCE_NAME" 2>/dev/null); then
    echo "Container not found: $INSTANCE_NAME" >&2
    exit 1
fi

if ! printf '%s\n' "$INSPECTION" | \
    grep -Eq '"com\.matx\.p5-local-lab\.managed"[[:space:]]*:[[:space:]]*"true"'; then
    echo "Refusing to delete $INSTANCE_NAME: it is not labelled as a P5 Local Lab container." >&2
    exit 1
fi

if printf '%s\n' "$INSPECTION" | \
    grep -Eq '"state"[[:space:]]*:[[:space:]]*"running"'; then
    "$CONTAINER_BIN" stop --time 30 "$INSTANCE_NAME"
fi

"$CONTAINER_BIN" delete "$INSTANCE_NAME"
echo "Deleted container $INSTANCE_NAME."
echo "Preserved $P5_LAB_ROOT/instances/$INSTANCE_NAME"


