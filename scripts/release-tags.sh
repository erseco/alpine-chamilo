#!/bin/sh
# Prints the image tags for a release: X.Y.Z, plus X.Y, X and latest when X.Y.Z is
# the newest stable release in that range. Usage: release-tags.sh X.Y.Z < git-tags
set -eu
version=$1
releases=$(grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sed 's/^v//' | sort -V)
newest() { printf '%s\n' "$releases" | grep -E "^$1" | tail -n 1; }
minor=${version%.*}
major=${version%%.*}
tags=$version
[ "$(newest "${minor}\\.")" != "$version" ] || tags="$tags $minor"
[ "$(newest "${major}\\.")" != "$version" ] || tags="$tags $major"
[ "$(newest '')" != "$version" ] || tags="$tags latest"
printf '%s\n' "$tags"
