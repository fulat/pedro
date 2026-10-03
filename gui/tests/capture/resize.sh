#!/usr/bin/env bash
set -euo pipefail
sourceDirectory=$(cd "$(dirname "$0")/../../.." && pwd)
taskDirectory="$sourceDirectory/build/verification/capture"
mkdir -p "$taskDirectory"
/usr/lib/qt6/libexec/moc "$sourceDirectory/gui/tests/capture/resize.cpp" -o "$taskDirectory/resize.moc"
read -r -a flags <<< "$(pkg-config --cflags --libs Qt6Quick Qt6Qml Qt6Test Qt6Svg)"
c++ -std=c++17 -fPIC -I "$sourceDirectory" -I "$taskDirectory" \
    "$sourceDirectory/gui/tests/capture/resize.cpp" \
    "${flags[@]}" -o "$taskDirectory/resize"
QT_QPA_PLATFORM=offscreen "$taskDirectory/resize" \
    "$sourceDirectory/gui/qml/components/capture/view.qml" "$sourceDirectory/gui"
