#!/bin/sh

set -eu
# shellcheck source=common.sh
. "$(dirname -- "$0")/common.sh"

INSTANCE_NAME=${1:-p5-lab-01}
HOST_PORT=${2:-20000}
validate_instance_name "$INSTANCE_NAME"
validate_port "$HOST_PORT"

INSTANCE_ROOT="$P5_LAB_ROOT/instances/$INSTANCE_NAME"
"$P5_LAB_ROOT/scripts/prepare-instance-folder.sh" "$INSTANCE_NAME" >/dev/null

if "$CONTAINER_BIN" inspect "$INSTANCE_NAME" >/dev/null 2>&1; then
    echo "Container $INSTANCE_NAME already exists; refusing to replace it." >&2
    exit 1
fi

echo "Creating $INSTANCE_NAME at http://127.0.0.1:$HOST_PORT/login"
"$CONTAINER_BIN" run \
    --detach \
    --name "$INSTANCE_NAME" \
    --platform linux/amd64 \
    --rosetta \
    --cpus 4 \
    --memory 4G \
    --label com.matx.p5-local-lab.managed=true \
    --label "com.matx.p5-local-lab.instance=$INSTANCE_NAME" \
    --publish "127.0.0.1:$HOST_PORT:8000" \
    --volume "$INSTANCE_ROOT:/host_dir" \
    "$P5_IMAGE_TAG"

echo "Created $INSTANCE_NAME. Run scripts/smoke-test.sh $INSTANCE_NAME $HOST_PORT."

