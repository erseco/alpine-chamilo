#!/bin/sh
# Alias rules for published image tags.
set -eu
check() {
    expected=$1 version=$2
    shift 2
    actual=$(printf '%s\n' "$@" | scripts/release-tags.sh "$version")
    [ "$actual" = "$expected" ] || { echo >&2 "$version with $*: got '$actual', want '$expected'"; exit 1; }
}
check '3.0.2 3.0 3 latest' 3.0.2 v3.0.2 v3.0.2-r1
check '3.0.10 3.0 3 latest' 3.0.10 v3.0.2 v3.0.9 v3.0.10
check '3.0.3 3.0' 3.0.3 v3.0.3 v3.1.0
check '3.1.0 3.1 3' 3.1.0 v3.1.0 v4.0.0
check '3.0.2' 3.0.2 v3.0.2 v3.0.3
check '30.0.1 30.0 30 latest' 30.0.1 v3.0.2 v30.0.1
echo 'Release tag checks passed.'
