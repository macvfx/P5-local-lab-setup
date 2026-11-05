#!/bin/sh

set -eu
# shellcheck source=common.sh
. "$(dirname -- "$0")/common.sh"

INSTANCE_NAME=${1:-p5-lab-01}
validate_instance_name "$INSTANCE_NAME"
"$CONTAINER_BIN" stop --time 30 "$INSTANCE_NAME"

