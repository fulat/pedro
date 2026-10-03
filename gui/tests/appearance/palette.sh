#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
output="$root/build/verification/palette"
mkdir -p "$output"
c++ -std=c++17 -fPIC "$root/gui/tests/appearance/palette.cpp" \
    "$root/gui/backend/appearance/palette.cpp" -o "$output/palette" \
    $(pkg-config --cflags --libs Qt6Core Qt6Gui)
"$output/palette" "$output/fixtures"
