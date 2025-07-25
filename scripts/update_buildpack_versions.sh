#!/bin/bash
RELEASE_VERSION="$1"
FILE_PATH="$2"

if [ -f "$FILE_PATH" ]; then
  sed -i "s|^version = \"[^\"]*\"|version = ${RELEASE_VERSION}|g" "$FILE_PATH"
  echo "Updated $FILE_PATH to version ${RELEASE_VERSION}"
else
  echo "Error: File not found at ${FILE_PATH}. Skipping update." >&2
  exit 1
fi
