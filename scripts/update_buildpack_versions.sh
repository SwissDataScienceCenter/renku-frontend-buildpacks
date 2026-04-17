#!/bin/bash
set -xeou pipefail
RELEASE_VERSION="$1"
FILE_PATH="$2"

buildpacks=$(ls -d buildpacks/*)

which dasel || (echo "dasel not found, please install it" && exit 100)

for bp in buildpacks; do
  bp_toml="$bp/buildpack.toml"
  echo "Updating buildpack version in $bp to $RELEASE_VERSION"
  dasel -i toml --root "buildpack.version=\"$RELEASE_VERSION\"" <"$bp_toml" >"$bp_toml.tmp"
  mv "$bp_toml.tmp" "$bp_toml"
done
