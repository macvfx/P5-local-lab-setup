#!/bin/sh

set -eu
# shellcheck source=tart-common.sh
. "$(dirname -- "$0")/tart-common.sh"

echo "P5 Local Lab macOS VM preflight (Tart)"

require_apple_silicon

MACOS_VERSION=$(sw_vers -productVersion)
MACOS_MAJOR=$(printf '%s\n' "$MACOS_VERSION" | cut -d. -f1)
echo "Host macOS: $MACOS_VERSION"
if [ "$MACOS_MAJOR" -lt 27 ]; then
    echo "Warning: stacked (space-sharing) clones require macOS 27. On this host, clones will fall back to full copies and need more free disk space." >&2
fi

if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew was not found; installing it non-interactively."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [ -x /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
fi

if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew install did not complete; brew is still not on PATH." >&2
    exit 1
fi
echo "Homebrew: $(brew --version | head -n 1)"

if ! command -v tart >/dev/null 2>&1; then
    echo "Tart was not found; updating Homebrew taps and installing it."
    brew update
    if ! brew install cirruslabs/cli/tart; then
        TART_TAP_DIR=$(brew --repository cirruslabs/cli 2>/dev/null || true)
        if [ -n "$TART_TAP_DIR" ] && [ -d "$TART_TAP_DIR" ]; then
            for TART_TAP_FORMULA in "$TART_TAP_DIR"/*.rb; do
                [ -f "$TART_TAP_FORMULA" ] || continue
                if grep -q 'depends_on :macos => :ventura' "$TART_TAP_FORMULA"; then
                    echo "Working around a known cirruslabs/homebrew-cli tap bug in $TART_TAP_FORMULA (see Docs/MACOS_VM_TART_SETUP.md)."
                    sed -i '' '/depends_on :macos => :ventura/d' "$TART_TAP_FORMULA"
                fi
            done
        fi
        if ! brew install cirruslabs/cli/tart; then
            echo "Homebrew still cannot install Tart; looking for an existing tart.app instead." >&2
            TART_APP=""
            for CANDIDATE in /Applications/tart.app "$HOME/Applications/tart.app"; do
                if [ -x "$CANDIDATE/Contents/MacOS/tart" ]; then
                    TART_APP=$CANDIDATE
                    break
                fi
            done
            if [ -n "$TART_APP" ]; then
                echo "Found $TART_APP; linking it onto PATH."
                mkdir -p /opt/homebrew/bin
                ln -sf "$TART_APP/Contents/MacOS/tart" /opt/homebrew/bin/tart
            else
                cat <<EOF >&2

Homebrew cannot currently install Tart from the cirruslabs/homebrew-cli tap
(more than one formula in it carries the same depends_on bug). Download the
current release archive from
https://github.com/cirruslabs/tart/releases/latest, move tart.app to
/Applications, then re-run this script. See Docs/MACOS_VM_TART_SETUP.md for
why the app bundle path matters for Bridged networking.
EOF
                exit 1
            fi
        fi
    fi
fi
echo "Tart: $(tart --version)"

require_free_space

echo "Preflight passed."
