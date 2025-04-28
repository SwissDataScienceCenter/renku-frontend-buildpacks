#!/usr/bin/env bash

# The image name excluding the tag
IMAGE=$1
# The location where the buildpack is located
BP_PATH=$2
# If set to anything the image will be pushed to the image repository
PUBLISH=$3

TAG=$(./bin/yq '.buildpack.version' "$BP_PATH/buildpack.toml")
echo "Building image $IMAGE:$TAG for buildpack at $BP_PATH"

if [[ -z $PUBLISH ]]; then
	echo "Will not publish the push the image to the repository"
	pack buildpack package "$IMAGE:$TAG" --config "$BP_PATH/package.toml" --target "linux/amd64" --format image
else
	echo "Found publish flag, will push the image to the repo"
	pack buildpack package "$IMAGE:$TAG" --config "$BP_PATH/package.toml" --target "linux/amd64" --format image --publish
fi
