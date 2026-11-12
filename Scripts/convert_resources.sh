#!/bin/bash
# Build the keyboard extension's memory-mapped data files from their JSON sources.
# Run after editing filtered_frequency_data.json or bigram_data.json, and commit the .bin output.
#
#   lexicon.bin      <- filtered_frequency_data.json  (Scripts/build_lexicon_bin.py)
#   ngram_model.bin  <- bigram_data.json              (Scripts/build_ngram_bin.py)
#
# The extension mmaps both files read-only and searches them in place, so they
# add no dirty memory and no load-time decode peak. The old binary plists are
# no longer read; do not add them back to the Shan target.

set -euo pipefail

SRCROOT="${SRCROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

python3 -I "${SRCROOT}/Scripts/build_lexicon_bin.py" --verify
python3 -I "${SRCROOT}/Scripts/build_ngram_bin.py" --verify
