#!/usr/bin/env bash
set -xeou pipefail

# The image name excluding the tag
IMAGE=$1
# If set to anything the image will be pushed to the image repository
PUBLISH=${2:-}

TAG=$(git describe --exact-match --tags || echo "")
if [[ -z $TAG ]]; then
  TAG=$(git rev-parse HEAD | cut -c -7)
fi

echo "Building run image $IMAGE:$TAG"
docker build -t "$IMAGE:$TAG" ./run-image/

if [[ -n $PUBLISH ]]; then
  echo "Found publish flag, will push the image to the repo"
  #docker push "$IMAGE:$TAG"
fi
