#!/bin/sh

# Creates one P5 Local Lab instance exactly as scripts/create-instance.sh
# does, plus a second bind mount: an existing host folder of source media,
# mounted READ-ONLY inside the container (default target: /media).
#
# The same media folder can be given to any number of instances. Each
# instance still gets its own writable instances/<name> folder at /host_dir
# for archive, restore, and export data.
#
# A mount cannot be added to a container that already exists. To give an
# existing instance this mount it must be destroyed and recreated, which
# discards the P5 configuration and any trial licence in its writable layer.

set -eu
# shellcheck source=common.sh
. "$(dirname -- "$0")/common.sh"

USAGE="Usage: $0 <media-folder> [instance-name] [rest-port] [cli-port] [version]"

MEDIA_ARG=${1:?"$USAGE"}
INSTANCE_NAME=${2:-p5-lab-01}
REST_HOST_PORT=${3:-20000}
CLI_HOST_PORT=${4:-29001}
MEDIA_TARGET=${P5_LAB_MEDIA_TARGET:-/media}

validate_instance_name "$INSTANCE_NAME"
validate_distinct_ports "$REST_HOST_PORT" "$CLI_HOST_PORT"
resolve_p5_version "${5:-}"

if [ ! -d "$MEDIA_ARG" ]; then
    echo "Media folder does not exist or is not a directory: $MEDIA_ARG" >&2
    exit 2
fi
# Resolve to an absolute physical path so the runtime never receives a
# relative path or a symlink it would interpret differently.
MEDIA_ROOT=$(CDPATH='' cd -- "$MEDIA_ARG" && pwd -P)

case "$MEDIA_ROOT" in
    /)
        echo "Refusing to mount the host root filesystem into P5." >&2
        exit 2
        ;;
    *:*|*,*)
        echo "Media folder path must not contain ':' or ',' (volume syntax separators): $MEDIA_ROOT" >&2
        exit 2
        ;;
esac

case "$MEDIA_TARGET" in
    /|/host_dir|/host_dir/|/usr/local/aw|/usr/local/aw/*)
        echo "P5_LAB_MEDIA_TARGET must not be /, /host_dir, or inside /usr/local/aw." >&2
        exit 2
        ;;
    /*)
        case "$MEDIA_TARGET" in
            *[!A-Za-z0-9/_-]*)
                echo "P5_LAB_MEDIA_TARGET may contain letters, numbers, '/', '_', and '-' only." >&2
                exit 2
                ;;
        esac
        ;;
    *)
        echo "P5_LAB_MEDIA_TARGET must be an absolute container path such as /media." >&2
        exit 2
        ;;
esac

if "$CONTAINER_BIN" inspect "$INSTANCE_NAME" >/dev/null 2>&1; then
    echo "Container $INSTANCE_NAME already exists; refusing to replace it." >&2
    echo "A mount cannot be added to an existing container." >&2
    exit 1
fi

# Checked before the instance folder is prepared, so a port clash leaves
# nothing behind for scripts/create-instances.sh to count.
require_free_ports "$REST_HOST_PORT" "$CLI_HOST_PORT"

INSTANCE_ROOT="$P5_LAB_ROOT/instances/$INSTANCE_NAME"
"$P5_LAB_ROOT/scripts/prepare-instance-folder.sh" "$INSTANCE_NAME" >/dev/null

echo "Creating $INSTANCE_NAME with REST on 127.0.0.1:$REST_HOST_PORT and CLI/awsock on 127.0.0.1:$CLI_HOST_PORT"
echo "Read-only source media: $MEDIA_ROOT -> $MEDIA_TARGET"
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
    --label "com.matx.p5-local-lab.media-target=$MEDIA_TARGET" \
    --publish "127.0.0.1:$REST_HOST_PORT:8000" \
    --publish "127.0.0.1:$CLI_HOST_PORT:9001" \
    --volume "$INSTANCE_ROOT:/host_dir" \
    --volume "$MEDIA_ROOT:$MEDIA_TARGET:ro" \
    "$P5_IMAGE_TAG"

echo "Checking that $MEDIA_TARGET is visible and read-only inside $INSTANCE_NAME."
# The quoted expression is intentionally evaluated by the container's shell.
# shellcheck disable=SC2016
if ! "$CONTAINER_BIN" exec "$INSTANCE_NAME" /bin/sh -c \
    'test -d "$1"' sh "$MEDIA_TARGET"; then
    echo "$MEDIA_TARGET is not visible inside $INSTANCE_NAME." >&2
    echo "The container was left in place for inspection." >&2
    exit 1
fi

# The probe file is removed again if the write unexpectedly succeeds, so a
# mount that is not read-only never leaves a stray file in the media folder.
PROBE="$MEDIA_TARGET/.p5-local-lab-write-probe"
# shellcheck disable=SC2016
if "$CONTAINER_BIN" exec "$INSTANCE_NAME" /bin/sh -c \
    'if touch "$1" 2>/dev/null; then rm -f "$1"; exit 0; fi; exit 1' \
    sh "$PROBE"; then
    echo "$MEDIA_TARGET is WRITABLE inside $INSTANCE_NAME; the read-only mount was not honoured." >&2
    echo "Do not point P5 at this media. Remove the instance with:" >&2
    echo "  ./scripts/destroy-instance.sh $INSTANCE_NAME --confirm" >&2
    exit 1
fi

echo "Created $INSTANCE_NAME. Source media is read-only at $MEDIA_TARGET."
echo "Run scripts/smoke-test.sh $INSTANCE_NAME $REST_HOST_PORT $CLI_HOST_PORT."
