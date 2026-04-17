#!/bin/bash
set -xeou pipefail
BUILD_IMAGE="$1"
BUILDER_FILE="$2"

which dasel || (echo "dasel not found, please install it" && exit 100)

dasel -i toml --root "build.image=\"$BUILD_IMAGE\"" <"$BUILDER_FILE" >"$BUILDER_FILE.tmp"
mv "$BUILDER_FILE.tmp" "$BUILDER_FILE"
