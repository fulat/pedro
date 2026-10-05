#!/usr/bin/env bash
set -euo pipefail
sourceDirectory=$(cd "$(dirname "$0")/../../.." && pwd)
taskDirectory="$sourceDirectory/build/verification/content/icons"
mkdir -p "$taskDirectory/data/icons/hicolor/scalable/apps"
cat > "$taskDirectory/data/icons/hicolor/scalable/apps/pedro-test-icon.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18"><rect width="18" height="18" fill="red"/></svg>
SVG
read -r -a flags <<< "$(pkg-config --cflags --libs Qt6Quick Qt6Svg)"
c++ -std=c++17 -fPIC -I "$sourceDirectory/gui/backend" \
    "$sourceDirectory/gui/tests/content/icons.cpp" \
    "$sourceDirectory/gui/backend/application/icon/provider.cpp" \
    "${flags[@]}" -o "$taskDirectory/check"
XDG_DATA_HOME="$taskDirectory/data" QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=none \
    "$taskDirectory/check"
