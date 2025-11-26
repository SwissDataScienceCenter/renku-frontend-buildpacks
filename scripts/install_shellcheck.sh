#!/usr/bin/env bash
set -xeou pipefail

# The tag i.e. version for the release to download - optional, default is latest
VERSION=$1
# Download location folder, i.e. /usr/bin - optional, default is ./bin
LOCATION=$2

OS="linux"
ARCH="x86_64"

if [[ -z $VERSION ]]; then
	VERSION="latest"
fi

if [[ -z $LOCATION ]]; then
	LOCATION="./bin"
fi

if [ -f "$LOCATION/shellcheck" ]; then
	echo "Already found shellcheck installed in $LOCALBIN"
	exit 0
fi

ALREADY_EXISTS=$(which shellcheck)
if [ -n "$ALREADY_EXISTS" ]; then
	echo "Already found shellcheck installed elsewhere, linking in $LOCALBIN"
	ln -s "$ALREADY_EXISTS" "$LOCATION/shellcheck"
	exit 0
fi

if [ -d "$LOCATION/shellcheck-$VERSION" ] && [ -f "$LOCATION/shellcheck" ]; then
	echo "Shellcheck found."
else
	echo "Shellcheck not found, will download"
	rm -rf "$LOCATION/shellcheck-$VERSION"
	rm -rf "$LOCATION/shellcheck"
	curl -sSL "https://github.com/koalaman/shellcheck/releases/download/$VERSION/shellcheck-$VERSION.$OS.$ARCH.tar.xz" | tar -xJ -C "$LOCATION"
	ln -s "$LOCATION/shellcheck-$VERSION/shellcheck" "$LOCATION/shellcheck"
fi
