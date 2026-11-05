#!/bin/sh

set -eu
# shellcheck source=common.sh
. "$(dirname -- "$0")/common.sh"

INSTANCE_NAME=${1:-p5-lab-01}
validate_instance_name "$INSTANCE_NAME"

INSTANCE_ROOT="$P5_LAB_ROOT/instances/$INSTANCE_NAME"
mkdir -p \
    "$INSTANCE_ROOT/source" \
    "$INSTANCE_ROOT/archive" \
    "$INSTANCE_ROOT/restore" \
    "$INSTANCE_ROOT/exports"

echo "$INSTANCE_ROOT"
