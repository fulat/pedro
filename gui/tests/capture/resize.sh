#!/usr/bin/env bash
set -euo pipefail
sourceDirectory=$(cd "$(dirname "$0")/../../.." && pwd)
taskDirectory="$sourceDirectory/build/verification/capture"
mkdir -p "$taskDirectory"
/usr/lib/qt6/libexec/moc "$sourceDirectory/papi/gui/capture/manager.h" -o "$taskDirectory/moc.cpp"
/usr/lib/qt6/libexec/moc "$sourceDirectory/gui/tests/capture/resize.cpp" -o "$taskDirectory/resize.moc"
read -r -a flags <<< "$(pkg-config --cflags --libs Qt6Quick Qt6Qml Qt6DBus Qt6Test)"
c++ -std=c++17 -fPIC -I "$sourceDirectory" -I "$taskDirectory" \
    "$sourceDirectory/gui/tests/capture/resize.cpp" \
    "$sourceDirectory/papi/gui/capture/manager.cpp" "$taskDirectory/moc.cpp" \
    "${flags[@]}" -o "$taskDirectory/resize"
QT_QPA_PLATFORM=offscreen dbus-run-session -- "$taskDirectory/resize" \
    "$sourceDirectory/gui/qml/components/capture/view.qml"
