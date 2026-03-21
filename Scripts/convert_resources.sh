#!/bin/bash
# Convert JSON resource files to binary plist for faster parsing.
# Run as an Xcode "Run Script" build phase before "Copy Bundle Resources".
# Only reconverts when the JSON source is newer than the plist output.

set -euo pipefail

RESOURCE_DIR="${SRCROOT}/Shan/Autocomplete/Resource"

convert_if_needed() {
    local base="$1"
    local json="${RESOURCE_DIR}/${base}.json"
    local plist="${RESOURCE_DIR}/${base}.plist"

    if [ ! -f "$json" ]; then
        echo "warning: ${json} not found, skipping"
        return
    fi

    if [ ! -f "$plist" ] || [ "$json" -nt "$plist" ]; then
        echo "Converting ${base}.json → ${base}.plist"
        cp "$json" "$plist"
        plutil -convert binary1 "$plist"
    else
        echo "${base}.plist is up to date"
    fi
}

convert_if_needed "filtered_frequency_data"
convert_if_needed "bigram_data"
