#!/usr/bin/env bash
set -euo pipefail
sourceDirectory=$(cd "$(dirname "$0")/../../.." && pwd)
taskDirectory="$sourceDirectory/build/verification/entry"
mkdir -p "$taskDirectory"
read -r -a flags <<< "$(pkg-config --cflags --libs Qt6Gui)"
c++ -std=c++17 -fPIC "$sourceDirectory/gui/tests/entry/name.cpp" \
    "$sourceDirectory/gui/backend/entry/name.cpp" "${flags[@]}" -o "$taskDirectory/name"
QT_QPA_PLATFORM=offscreen "$taskDirectory/name"
