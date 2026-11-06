#!/bin/sh

set -eu
# shellcheck source=tart-common.sh
. "$(dirname -- "$0")/tart-common.sh"

GOLDEN_NAME=${1:?"Usage: $0 <golden-name> <image-reference>"}
IMAGE_REF=${2:?"Usage: $0 <golden-name> <image-reference>"}

resolve_tart_bin
require_free_space

if [ -d "$HOME/.tart/vms/$GOLDEN_NAME" ]; then
    echo "$GOLDEN_NAME already exists; refusing to replace a golden image." >&2
    echo "Delete it first with: $TART_BIN delete $GOLDEN_NAME" >&2
    exit 1
fi

echo "Cloning $IMAGE_REF as $GOLDEN_NAME"
"$TART_BIN" clone "$IMAGE_REF" "$GOLDEN_NAME"

cat <<EOF

$GOLDEN_NAME created from $IMAGE_REF.

The remaining steps are manual by design (see Docs/MACOS_VM_TART_SETUP.md):
  1. $TART_BIN run $GOLDEN_NAME
  2. Complete Setup Assistant using a dedicated, fictional automation account.
  3. Install current OS updates and confirm the Tart guest agent is present.
  4. Do not install P5 or any credential into this image.
  5. $TART_BIN stop $GOLDEN_NAME
  6. Treat $GOLDEN_NAME as read-only from now on; clone from it for every
     test instead of booting it directly.
EOF
