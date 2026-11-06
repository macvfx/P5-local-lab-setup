#!/bin/sh

set -eu

# shellcheck disable=SC2034
P5_LAB_ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
# shellcheck disable=SC2034
P5_IMAGE_TAG="p5-lab:8.0.6"

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

