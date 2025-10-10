#!/usr/bin/env bash

# The image name excluding the tag
IMAGE=$1
# The location where the builder is located
BUILDER_PATH=$2
# If set to anything the image will be pushed to the image repository
PUBLISH=$3

TAG=$(git describe --exact-match --tags)
if [[ -z $TAG ]]; then
	TAG=$(git rev-parse HEAD | cut -c -7)
fi
echo "Building image $IMAGE:$TAG for builder at $BUILDER_PATH"

if [[ -z $PUBLISH ]]; then
	echo "Will not publish the push the image to the repository"
	pack builder create "$IMAGE:$TAG" --config "$BUILDER_PATH/builder.toml"
else
	echo "Found publish flag, will push the image to the repo"
	pack builder create "$IMAGE:$TAG" --config "$BUILDER_PATH/builder.toml" --publish
fi
