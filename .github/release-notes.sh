#!/bin/sh
set -e
notes=$(awk -v v="$1" '
    /^## / { if (found) exit; found = ($2 == v) ; next }
    found
' "$(dirname "$0")/../CHANGELOG.md" | sed -e '/./,$!d')
if [ -z "$notes" ]; then
    echo "CHANGELOG.md has no section for $1" >&2
    exit 1
fi
printf '%s\n\n' "$notes"
echo "Requires macOS 12 or later. See the [install instructions](https://github.com/glorat/nethack-cocoa#install) for how to open it the first time."
