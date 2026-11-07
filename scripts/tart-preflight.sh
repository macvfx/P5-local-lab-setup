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
        cat <<EOF >&2

brew install cirruslabs/cli/tart failed even after 'brew update'. This is a
known failure mode where the cirruslabs/homebrew-cli tap's auto-generated
formula uses a 'depends_on' ordering current Homebrew now refuses outright.
Check https://github.com/cirruslabs/tart/releases for a newer tap fix, or
install Tart from a release archive instead of Homebrew: run the binary at
tart.app/Contents/MacOS/tart from the extracted app bundle (not the bare
binary), since that path carries the embedded provisioning profile Bridged
networking needs. See Docs/MACOS_VM_TART_SETUP.md for details.
EOF
        exit 1
    fi
fi
echo "Tart: $(tart --version)"

require_free_space

echo "Preflight passed."
