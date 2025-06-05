#!/usr/bin/env bash
set -e

echo "Feature to install pack CLI"

download_url="https://github.com/buildpacks/pack/releases/download/$VERSION/pack-$VERSION-linux.tgz"
echo "Installing pack CLI from $download_url"

curl -sSL -o pack.tgz "$download_url"
tar -C /usr/local/bin -xzf pack.tgz
chmod 777 /usr/local/bin/pack
rm -rf pack.tgz
