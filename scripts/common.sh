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
            exit 1
        fi
    done
}
