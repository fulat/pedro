#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
output="$root/build/verification/glass"
mkdir -p "$output"
c++ -std=c++17 -fPIC "$root/gui/tests/window/glass.cpp" -o "$output/glass" \
    $(pkg-config --cflags --libs Qt6Quick Qt6Qml Qt6Svg)
QT_QPA_PLATFORM=xcb QT_QPA_PLATFORMTHEME=none PEDRO_QML_DIR="$root/gui" \
    "$output/glass" "$root/gui/qml/components/window/frame.qml"
