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

REST_BASE=20000
CLI_BASE=29001

HIGHEST=0
for DIR in "$P5_LAB_ROOT"/instances/"$NAME_PREFIX"-*; do
    [ -d "$DIR" ] || continue
    NAME=$(basename "$DIR")
    SUFFIX=${NAME#"$NAME_PREFIX"-}
    case "$SUFFIX" in
        ''|*[!0-9]*) continue ;;
    esac
    # Strip leading zeros before arithmetic: POSIX shell arithmetic treats
    # a leading-zero numeral as octal, which fails outright on "08"/"09".
    SUFFIX_TRIMMED=$(printf '%s' "$SUFFIX" | sed 's/^0*//')
    if [ -z "$SUFFIX_TRIMMED" ]; then
        SUFFIX_NUM=0
    else
        SUFFIX_NUM=$((SUFFIX_TRIMMED))
    fi
    if [ "$SUFFIX_NUM" -gt "$HIGHEST" ]; then
        HIGHEST=$SUFFIX_NUM
    fi
done

echo "Highest existing $NAME_PREFIX-NN instance: $HIGHEST"

SMOKE_TEST_COMMANDS=""
CREATED=0
OFFSET=1
while [ "$CREATED" -lt "$COUNT" ]; do
    NEXT=$((HIGHEST + OFFSET))
    NEXT_PADDED=$(printf '%02d' "$NEXT")
    INSTANCE_NAME="$NAME_PREFIX-$NEXT_PADDED"
    REST_PORT=$((REST_BASE + NEXT - 1))
    CLI_PORT=$((CLI_BASE + NEXT - 1))

    echo "Creating instance $((CREATED + 1)) of $COUNT: $INSTANCE_NAME (REST $REST_PORT, CLI $CLI_PORT)"
    "$P5_LAB_ROOT/scripts/create-instance.sh" "$INSTANCE_NAME" "$REST_PORT" "$CLI_PORT" "$VERSION_ARG"
    SMOKE_TEST_COMMANDS="$SMOKE_TEST_COMMANDS
  ./scripts/smoke-test.sh $INSTANCE_NAME $REST_PORT $CLI_PORT"

    OFFSET=$((OFFSET + 1))
    CREATED=$((CREATED + 1))
done

echo "Created $CREATED instance(s). Run scripts/smoke-test.sh against each to verify:"
printf '%s\n' "$SMOKE_TEST_COMMANDS"
