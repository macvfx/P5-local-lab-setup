#!/bin/sh

set -eu

# shellcheck disable=SC2034
TART_MIN_FREE_GB=${TART_MIN_FREE_GB:-150}

require_apple_silicon() {
    if [ "$(sysctl -n hw.optional.arm64 2>/dev/null || echo 0)" != "1" ]; then
        echo "This workflow requires an Apple silicon Mac." >&2
        exit 1
    fi
}

require_free_space() {
    AVAIL_GB=$(df -g / | awk 'NR==2 { print $4 }')
    if [ "$AVAIL_GB" -lt "$TART_MIN_FREE_GB" ]; then
        echo "Only ${AVAIL_GB}GB free on /; at least ${TART_MIN_FREE_GB}GB is required before pulling or cloning macOS VM images." >&2
        exit 1
    fi
    echo "Free space check passed: ${AVAIL_GB}GB available (minimum ${TART_MIN_FREE_GB}GB)."
}

resolve_tart_bin() {
    if [ -n "${TART_BIN:-}" ]; then
        return 0
    elif [ -x /opt/homebrew/bin/tart ]; then
        TART_BIN=/opt/homebrew/bin/tart
    elif command -v tart >/dev/null 2>&1; then
        TART_BIN=$(command -v tart)
    else
        echo "Tart was not found. Run scripts/tart-preflight.sh first." >&2
        exit 1
    fi
}
