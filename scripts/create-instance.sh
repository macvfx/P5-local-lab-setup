#!/bin/sh

set -eu
# shellcheck source=common.sh
. "$(dirname -- "$0")/common.sh"

# shellcheck disable=SC2034
NEXT_HINT_COMMAND="./scripts/create-instance.sh"

print_help() {
    cat <<HELP
Usage:
  $0 [instance-name] [rest-port] [cli-port] [version]
  $0 --next [version]
  $0 --help

Creates one P5 Local Lab instance. With no arguments it uses p5-lab-01 on
REST port 20000 and CLI port 29001.

  --next   Pick the next free p5-lab-NN name and its ports automatically.
  --help   Show this help, the instances that exist, and the next free
           name and ports. Creates nothing.

Existing instances:
HELP
    print_instances_overview
    echo
    print_next_available
}

VERSION_ARG=""
case "${1:-}" in
    -h|--help|help)
        print_help
        exit 0
        ;;
    --next)
        if ! suggest_next_instance "$LAB_DEFAULT_PREFIX"; then
            echo "No free $LAB_DEFAULT_PREFIX-NN name and port pair was found in the next 50 numbers." >&2
            exit 1
        fi
        INSTANCE_NAME=$NEXT_INSTANCE_NAME
        REST_HOST_PORT=$NEXT_REST_PORT
        CLI_HOST_PORT=$NEXT_CLI_PORT
        VERSION_ARG=${2:-}
        ;;
    -*)
        echo "Unknown option: $1. Run $0 --help." >&2
        exit 2
        ;;
    *)
        INSTANCE_NAME=${1:-p5-lab-01}
        REST_HOST_PORT=${2:-20000}
        CLI_HOST_PORT=${3:-29001}
        VERSION_ARG=${4:-}
        ;;
esac
validate_instance_name "$INSTANCE_NAME"
validate_distinct_ports "$REST_HOST_PORT" "$CLI_HOST_PORT"
resolve_p5_version "$VERSION_ARG"

if "$CONTAINER_BIN" inspect "$INSTANCE_NAME" >/dev/null 2>&1; then
    echo "Container $INSTANCE_NAME already exists; refusing to replace it." >&2
    print_next_available >&2
    exit 1
fi

# Checked before the instance folder is prepared, so a port clash leaves
# nothing behind for scripts/create-instances.sh to count.
require_free_ports "$REST_HOST_PORT" "$CLI_HOST_PORT"

INSTANCE_ROOT="$P5_LAB_ROOT/instances/$INSTANCE_NAME"
"$P5_LAB_ROOT/scripts/prepare-instance-folder.sh" "$INSTANCE_NAME" >/dev/null

echo "Creating $INSTANCE_NAME with REST on 127.0.0.1:$REST_HOST_PORT and CLI/awsock on 127.0.0.1:$CLI_HOST_PORT"
"$CONTAINER_BIN" run \
    --detach \
    --name "$INSTANCE_NAME" \
    --platform linux/amd64 \
    --rosetta \
    --cpus 4 \
    --memory 4G \
    --label com.matx.p5-local-lab.managed=true \
    --label "com.matx.p5-local-lab.instance=$INSTANCE_NAME" \
    --label "com.matx.p5-local-lab.p5-version=$P5_VERSION" \
    --publish "127.0.0.1:$REST_HOST_PORT:8000" \
    --publish "127.0.0.1:$CLI_HOST_PORT:9001" \
    --volume "$INSTANCE_ROOT:/host_dir" \
    "$P5_IMAGE_TAG"

echo "Created $INSTANCE_NAME. Run scripts/smoke-test.sh $INSTANCE_NAME $REST_HOST_PORT $CLI_HOST_PORT."

