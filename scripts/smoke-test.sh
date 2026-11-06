#!/bin/sh

set -eu
# shellcheck source=common.sh
. "$(dirname -- "$0")/common.sh"

INSTANCE_NAME=${1:-p5-lab-01}
REST_HOST_PORT=${2:-20000}
CLI_HOST_PORT=${3:-29001}
validate_instance_name "$INSTANCE_NAME"
validate_distinct_ports "$REST_HOST_PORT" "$CLI_HOST_PORT"

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

echo "Checking P5 CLI inside the container."
P5_VERSION=$("$CONTAINER_BIN" exec "$INSTANCE_NAME" \
    /usr/local/aw/bin/nsdchat -c srvinfo lexxvers)
if [ -z "$P5_VERSION" ]; then
    echo "The internal P5 CLI returned no version." >&2
    exit 1
fi
echo "Internal P5 CLI returned version $P5_VERSION"

echo "Waiting up to 120 seconds for the P5 login page."
ATTEMPT=0
while [ "$ATTEMPT" -lt 60 ]; do
    if curl --fail --silent \
        --output /dev/null \
        "http://127.0.0.1:$REST_HOST_PORT/login"; then
        echo "P5 responded at http://127.0.0.1:$REST_HOST_PORT/login"
        echo "Checking the published CLI/awsock TCP port."
        if ! command -v nc >/dev/null 2>&1; then
            echo "The nc utility required for the host-side CLI port check was not found." >&2
            exit 1
        fi
        if ! nc -z -w 5 127.0.0.1 "$CLI_HOST_PORT"; then
            echo "P5 CLI/awsock did not accept a TCP connection on 127.0.0.1:$CLI_HOST_PORT." >&2
            exit 1
        fi
        echo "P5 CLI/awsock accepted a TCP connection on 127.0.0.1:$CLI_HOST_PORT"
        echo "Smoke test passed. Unlicensed read-only REST and remote CLI testing is available."
        echo "Trial activation for configured Archive workflows remains optional and manual."
        exit 0
    fi
    ATTEMPT=$((ATTEMPT + 1))
    sleep 2
done

echo "P5 did not become ready. Recent container logs follow." >&2
"$CONTAINER_BIN" logs -n 100 "$INSTANCE_NAME" >&2
exit 1


