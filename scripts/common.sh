#!/bin/sh

set -eu

# shellcheck source=versions-common.sh
. "$(dirname -- "$0")/versions-common.sh"

if [ -n "${P5_CONTAINER_BIN:-}" ]; then
    # shellcheck disable=SC2034
    CONTAINER_BIN=$P5_CONTAINER_BIN
elif [ -x /usr/local/bin/container ]; then
    # shellcheck disable=SC2034
    CONTAINER_BIN=/usr/local/bin/container
elif [ -x /opt/homebrew/bin/container ]; then
    # shellcheck disable=SC2034
    CONTAINER_BIN=/opt/homebrew/bin/container
else
    echo "Apple's container CLI was not found." >&2
    exit 1
fi

validate_instance_name() {
    case "$1" in
        ""|*[!a-z0-9-]*)
            echo "Instance names may contain lowercase letters, numbers, and hyphens only." >&2
            exit 2
            ;;
    esac
}

validate_port() {
    case "$1" in
        ""|*[!0-9]*)
            echo "Port must be a number from 1 through 65535." >&2
            exit 2
            ;;
    esac
    if [ "$1" -lt 1 ] || [ "$1" -gt 65535 ]; then
        echo "Port must be a number from 1 through 65535." >&2
        exit 2
    fi
}

validate_distinct_ports() {
    validate_port "$1"
    validate_port "$2"
    if [ "$1" -eq "$2" ]; then
        echo "REST and CLI host ports must be different." >&2
        exit 2
    fi
}

# True when something on this Mac is already listening on 127.0.0.1:<port>.
# A stopped container does not hold its ports, so this only sees live
# listeners. Without nc the check is skipped and reports the port as free.
port_in_use() {
    command -v nc >/dev/null 2>&1 || return 1
    nc -z -w 1 127.0.0.1 "$1" >/dev/null 2>&1
}

require_free_ports() {
    for CHECK_PORT in "$@"; do
        if port_in_use "$CHECK_PORT"; then
            echo "Host port $CHECK_PORT is already in use on 127.0.0.1; nothing was created." >&2
            echo "Find what holds it with: lsof -nP -iTCP:$CHECK_PORT -sTCP:LISTEN" >&2
            print_next_available >&2
            exit 1
        fi
        if port_claimed "$CHECK_PORT"; then
            echo "Host port $CHECK_PORT belongs to an existing lab container that is not running; nothing was created." >&2
            echo "Two instances sharing a port cannot run at the same time." >&2
            print_next_available >&2
            exit 1
        fi
    done
}

# --- What already exists, and what is free next ---------------------------

LAB_REST_BASE=20000
LAB_CLI_BASE=29001
LAB_DEFAULT_PREFIX=p5-lab

# Names of the folders under instances/, one per line.
instance_names() {
    for INSTANCE_DIR in "$P5_LAB_ROOT"/instances/*/; do
        [ -d "$INSTANCE_DIR" ] || continue
        basename "$INSTANCE_DIR"
    done
}

# Best effort: the host ports a container was created with, read from the
# runtime's inspect JSON. Prints nothing when the container does not exist
# or the JSON has no "hostPort" fields.
container_host_ports() {
    "$CONTAINER_BIN" inspect "$1" 2>/dev/null |
        grep -Eo '"hostPort"[[:space:]]*:[[:space:]]*[0-9]+' |
        grep -Eo '[0-9]+$' | tr '\n' ' '
}

# Collects the host ports of every container that has an instance folder,
# running or not, so a stopped instance's ports are not handed out again.
CLAIMED_PORTS=""
CLAIMED_PORTS_LOADED=0
load_claimed_ports() {
    [ "$CLAIMED_PORTS_LOADED" -eq 1 ] && return 0
    CLAIMED_PORTS=" "
    for CLAIM_NAME in $(instance_names); do
        CLAIMED_PORTS="$CLAIMED_PORTS$(container_host_ports "$CLAIM_NAME") "
    done
    CLAIMED_PORTS_LOADED=1
}

port_claimed() {
    load_claimed_ports
    case "$CLAIMED_PORTS" in
        *" $1 "*) return 0 ;;
    esac
    return 1
}

# Returns 0 when <name> <rest-port> <cli-port> can be used for a new
# instance. Otherwise returns 1 and sets SLOT_REASON.
instance_slot_free() {
    SLOT_REASON=""
    if [ -e "$P5_LAB_ROOT/instances/$1" ]; then
        SLOT_REASON="instance folder instances/$1 already exists"
    elif "$CONTAINER_BIN" inspect "$1" >/dev/null 2>&1; then
        SLOT_REASON="a container named $1 already exists"
    elif port_in_use "$2" || port_in_use "$3"; then
        SLOT_REASON="host port $2 or $3 is already in use"
    elif port_claimed "$2" || port_claimed "$3"; then
        SLOT_REASON="host port $2 or $3 belongs to an existing lab container that is not running"
    fi
    [ -z "$SLOT_REASON" ]
}

# Sets HIGHEST_INSTANCE to the highest NN among instances/<prefix>-NN.
highest_instance_number() {
    HIGHEST_INSTANCE=0
    for HIGHEST_DIR in "$P5_LAB_ROOT"/instances/"$1"-*; do
        [ -d "$HIGHEST_DIR" ] || continue
        HIGHEST_NAME=$(basename "$HIGHEST_DIR")
        HIGHEST_SUFFIX=${HIGHEST_NAME#"$1"-}
        case "$HIGHEST_SUFFIX" in
            ''|*[!0-9]*) continue ;;
        esac
        # Strip leading zeros before arithmetic: POSIX shell arithmetic treats
        # a leading-zero numeral as octal, which fails outright on "08"/"09".
        HIGHEST_TRIMMED=$(printf '%s' "$HIGHEST_SUFFIX" | sed 's/^0*//')
        if [ -n "$HIGHEST_TRIMMED" ] && [ "$HIGHEST_TRIMMED" -gt "$HIGHEST_INSTANCE" ]; then
            HIGHEST_INSTANCE=$HIGHEST_TRIMMED
        fi
    done
}

# Sets NEXT_INSTANCE_NAME, NEXT_REST_PORT and NEXT_CLI_PORT to the first free
# <prefix>-NN after the highest existing one, using the same numbering as
# scripts/create-instances.sh. Returns 1 if none of the next 50 is free.
suggest_next_instance() {
    SUGGEST_PREFIX=${1:-$LAB_DEFAULT_PREFIX}
    highest_instance_number "$SUGGEST_PREFIX"
    SUGGEST_N=$((HIGHEST_INSTANCE + 1))
    SUGGEST_LIMIT=$((HIGHEST_INSTANCE + 50))
    while [ "$SUGGEST_N" -le "$SUGGEST_LIMIT" ]; do
        NEXT_INSTANCE_NAME="$SUGGEST_PREFIX-$(printf '%02d' "$SUGGEST_N")"
        NEXT_REST_PORT=$((LAB_REST_BASE + SUGGEST_N - 1))
        NEXT_CLI_PORT=$((LAB_CLI_BASE + SUGGEST_N - 1))
        if instance_slot_free "$NEXT_INSTANCE_NAME" "$NEXT_REST_PORT" "$NEXT_CLI_PORT"; then
            return 0
        fi
        SUGGEST_N=$((SUGGEST_N + 1))
    done
    return 1
}

# One line per instance folder: name, container state, host ports.
print_instances_overview() {
    printf '%-24s %-10s %s\n' "INSTANCE" "CONTAINER" "HOST PORTS (REST CLI)"
    OVERVIEW_COUNT=0
    for OVERVIEW_NAME in $(instance_names); do
        OVERVIEW_COUNT=$((OVERVIEW_COUNT + 1))
        if OVERVIEW_JSON=$("$CONTAINER_BIN" inspect "$OVERVIEW_NAME" 2>/dev/null); then
            if printf '%s\n' "$OVERVIEW_JSON" |
                grep -Eq '"(state|status)"[[:space:]]*:[[:space:]]*"running"'; then
                OVERVIEW_STATE="running"
            else
                OVERVIEW_STATE="stopped"
            fi
            OVERVIEW_PORTS=$(container_host_ports "$OVERVIEW_NAME")
            [ -n "$OVERVIEW_PORTS" ] || OVERVIEW_PORTS="unknown"
        else
            OVERVIEW_STATE="none"
            OVERVIEW_PORTS="-"
        fi
        printf '%-24s %-10s %s\n' "$OVERVIEW_NAME" "$OVERVIEW_STATE" "$OVERVIEW_PORTS"
    done
    if [ "$OVERVIEW_COUNT" -eq 0 ]; then
        echo "(no instances yet)"
    fi
}

# Prints the command for the next free name and ports. Scripts set
# NEXT_HINT_COMMAND to their own invocation, including any leading arguments.
print_next_available() {
    NEXT_HINT=${NEXT_HINT_COMMAND:-./scripts/create-instance.sh}
    if suggest_next_instance "$LAB_DEFAULT_PREFIX"; then
        echo "Next available:"
        echo "  $NEXT_HINT $NEXT_INSTANCE_NAME $NEXT_REST_PORT $NEXT_CLI_PORT"
        echo "Or let the script choose them:"
        echo "  $NEXT_HINT --next"
    else
        echo "No free $LAB_DEFAULT_PREFIX-NN name and port pair was found in the next 50 numbers."
    fi
}
