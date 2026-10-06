#!/usr/bin/env bash
set -euo pipefail
sourceDirectory=$(cd "$(dirname "$0")/../../.." && pwd)
taskDirectory="$sourceDirectory/build/verification/entry/drag"
mkdir -p "$taskDirectory"
read -r -a flags <<< "$(pkg-config --cflags --libs Qt6Quick Qt6Test)"
c++ -std=c++17 -fPIC -I "$sourceDirectory/gui/backend" \
    "$sourceDirectory/gui/tests/entry/drag.cpp" \
    "$sourceDirectory/gui/backend/entry/drag/image.cpp" \
    "${flags[@]}" -o "$taskDirectory/check"
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software "$taskDirectory/check"
