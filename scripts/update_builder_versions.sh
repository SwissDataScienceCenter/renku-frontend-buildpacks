#!/bin/bash
IMAGE="$1"
RELEASE_VERSION="$2"
BUILDER_FILE="$3"

# Use awk to properly handle TOML sections for buildpacks
awk -v version="$RELEASE_VERSION" \
'
/^\[\[buildpacks\]\]/ {
    print
    in_buildpack=1
    local_buildpack=0
    next
}
/^\[\[/ && !/^\[\[buildpacks\]\]/ {
    in_buildpack=0
    local_buildpack=0
}
in_buildpack && /^[[:space:]]*uri = "\.\.\/\.\.\/buildpacks\// {
    local_buildpack=1
}
in_buildpack && local_buildpack && /^[[:space:]]*version = / {
    gsub(/version = "[^"]*"/, "version = \"" version "\"")
}
{ print }
' "$BUILDER_FILE" > "${BUILDER_FILE}.tmp" && mv "${BUILDER_FILE}.tmp" "$BUILDER_FILE"

# Update run-image tag
sed -i 's|run-image = "[^"]*"|run-image = "'"${IMAGE}"':'"${RELEASE_VERSION}"'"|' "$BUILDER_FILE"

# Use awk for order group updates - track previous line for renku buildpacks
awk -v version="$RELEASE_VERSION" \
'
/^\[\[order\]\]/ {
    in_order=1
}
/^\[\[/ && !/^\[\[order\]\]/ && !/^\[\[order\.group\]\]/ {
    in_order=0
    prev_line_renku=0
}
in_order && /^[[:space:]]*id = "renku\// {
    prev_line_renku=1
    print
    next
}
in_order && prev_line_renku && /^[[:space:]]*version = / {
    gsub(/version = "[^"]*"/, "version = \"" version "\"")
    prev_line_renku=0
}
{
    if (!/^[[:space:]]*id = "renku\//) {
        prev_line_renku=0
    }
    print
}
' "$BUILDER_FILE" > "${BUILDER_FILE}.tmp" && mv "${BUILDER_FILE}.tmp" "$BUILDER_FILE"
