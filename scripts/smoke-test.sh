#!/bin/sh

set -eu
# shellcheck source=common.sh
. "$(dirname -- "$0")/common.sh"

INSTANCE_NAME=${1:-p5-lab-01}
HOST_PORT=${2:-20000}
validate_instance_name "$INSTANCE_NAME"
validate_port "$HOST_PORT"

INSTANCE_ROOT="$P5_LAB_ROOT/instances/$INSTANCE_NAME"
if [ ! -d "$INSTANCE_ROOT" ]; then
    echo "Instance folder does not exist: $INSTANCE_ROOT" >&2
    exit 1
fi

MARKER="$INSTANCE_ROOT/source/host-visible-marker.txt"
printf 'P5 Local Lab host visibility check\n' > "$MARKER"

echo "Checking AMD64 execution and the constrained host mount."
# The quoted expression is intentionally evaluated by the container's shell.
# shellcheck disable=SC2016
"$CONTAINER_BIN" exec "$INSTANCE_NAME" /bin/sh -c \
    'test "$(uname -m)" = "x86_64" && test -f /host_dir/source/host-visible-marker.txt'

echo "Waiting up to 120 seconds for the P5 login page."
ATTEMPT=0
while [ "$ATTEMPT" -lt 60 ]; do
    if curl --fail --silent \
        --output /dev/null \
        "http://127.0.0.1:$HOST_PORT/login"; then
        echo "P5 responded at http://127.0.0.1:$HOST_PORT/login"
        echo "Smoke test passed. Unlicensed read-only REST and CLI testing is available."
        echo "Trial activation for configured Archive workflows remains optional and manual."
        exit 0
    fi
    ATTEMPT=$((ATTEMPT + 1))
    sleep 2
done

echo "P5 did not become ready. Recent container logs follow." >&2
"$CONTAINER_BIN" logs -n 100 "$INSTANCE_NAME" >&2
exit 1


