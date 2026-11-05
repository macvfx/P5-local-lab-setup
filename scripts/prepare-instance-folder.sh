#!/bin/sh

set -eu

P5_LAB_ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)

INSTANCE_NAME=${1:-p5-lab-01}
case "$INSTANCE_NAME" in
    ""|*[!a-z0-9-]*)
        echo "Instance names may contain lowercase letters, numbers, and hyphens only." >&2
        exit 2
        ;;
esac

INSTANCE_ROOT="$P5_LAB_ROOT/instances/$INSTANCE_NAME"
mkdir -p \
    "$INSTANCE_ROOT/source" \
    "$INSTANCE_ROOT/archive" \
    "$INSTANCE_ROOT/restore" \
    "$INSTANCE_ROOT/exports"

echo "$INSTANCE_ROOT"
