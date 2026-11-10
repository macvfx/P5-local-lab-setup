#!/bin/sh

# Creates several P5 Local Lab instances in one call, auto-numbering names
# and incrementing REST/CLI ports from whatever p5-lab-NN instances already
# exist, instead of tracking names and ports by hand for each one.

set -eu
# shellcheck source=common.sh
. "$(dirname -- "$0")/common.sh"

COUNT=${1:?"Usage: $0 <count> [version] [name-prefix]"}
VERSION_ARG=${2:-}
NAME_PREFIX=${3:-p5-lab}

case "$COUNT" in
    ""|*[!0-9]*)
        echo "Count must be a positive whole number." >&2
        exit 2
        ;;
esac
if [ "$COUNT" -lt 1 ]; then
    echo "Count must be at least 1." >&2
    exit 2
fi

case "$NAME_PREFIX" in
    ""|*[!a-z0-9-]*)
        echo "Name prefix may contain lowercase letters, numbers, and hyphens only." >&2
        exit 2
        ;;
esac

# Optional: set P5_LAB_MEDIA to a host folder of source media and every
# instance created by this call gets it mounted read-only, through
# scripts/create-instance-with-media.sh. Checked once here so a bad path
# stops the batch before the first instance is created.
MEDIA_ROOT=${P5_LAB_MEDIA:-}
if [ -n "$MEDIA_ROOT" ] && [ ! -d "$MEDIA_ROOT" ]; then
    echo "P5_LAB_MEDIA does not exist or is not a directory: $MEDIA_ROOT" >&2
    exit 2
fi

highest_instance_number "$NAME_PREFIX"
HIGHEST=$HIGHEST_INSTANCE

echo "Highest existing $NAME_PREFIX-NN instance: $HIGHEST"

SMOKE_TEST_COMMANDS=""
CREATED=0
SKIPPED=0
OFFSET=1
while [ "$CREATED" -lt "$COUNT" ]; do
    NEXT=$((HIGHEST + OFFSET))
    NEXT_PADDED=$(printf '%02d' "$NEXT")
    INSTANCE_NAME="$NAME_PREFIX-$NEXT_PADDED"
    REST_PORT=$((LAB_REST_BASE + NEXT - 1))
    CLI_PORT=$((LAB_CLI_BASE + NEXT - 1))

    # The name and ports follow the instance number, but something outside
    # this numbering (a hand-made container, a ContainerManager stack, a
    # stopped instance, another app) may already hold them. Skip that number
    # rather than fail midway.
    if ! instance_slot_free "$INSTANCE_NAME" "$REST_PORT" "$CLI_PORT"; then
        SKIPPED=$((SKIPPED + 1))
        if [ "$SKIPPED" -gt 20 ]; then
            echo "More than 20 instance numbers were unavailable; stopping." >&2
            exit 1
        fi
        echo "Skipping $INSTANCE_NAME: $SLOT_REASON."
        OFFSET=$((OFFSET + 1))
        continue
    fi

    echo "Creating instance $((CREATED + 1)) of $COUNT: $INSTANCE_NAME (REST $REST_PORT, CLI $CLI_PORT)"
    if [ -n "$MEDIA_ROOT" ]; then
        "$P5_LAB_ROOT/scripts/create-instance-with-media.sh" "$MEDIA_ROOT" "$INSTANCE_NAME" "$REST_PORT" "$CLI_PORT" "$VERSION_ARG"
    else
        "$P5_LAB_ROOT/scripts/create-instance.sh" "$INSTANCE_NAME" "$REST_PORT" "$CLI_PORT" "$VERSION_ARG"
    fi
    SMOKE_TEST_COMMANDS="$SMOKE_TEST_COMMANDS
  ./scripts/smoke-test.sh $INSTANCE_NAME $REST_PORT $CLI_PORT"

    OFFSET=$((OFFSET + 1))
    CREATED=$((CREATED + 1))
done

echo "Created $CREATED instance(s). Run scripts/smoke-test.sh against each to verify:"
printf '%s\n' "$SMOKE_TEST_COMMANDS"
