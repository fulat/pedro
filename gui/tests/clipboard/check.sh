#!/usr/bin/env bash
set -euo pipefail
sourceDirectory=$(cd "$(dirname "$0")/../../.." && pwd)
taskDirectory="$sourceDirectory/build/verification/clipboard"
mkdir -p "$taskDirectory"
/usr/lib/qt6/libexec/moc "$sourceDirectory/papi/gui/clipboard/manager.hpp" -o "$taskDirectory/moc.cpp"
/usr/lib/qt6/libexec/moc "$sourceDirectory/papi/io/transfer/manager.hpp" -o "$taskDirectory/transfer.cpp"
read -r -a flags <<< "$(pkg-config --cflags --libs Qt6Gui Qt6Concurrent gio-2.0)"
c++ -std=c++17 -fPIC -I "$sourceDirectory/build/dev/papi/include" \
    "$sourceDirectory/gui/tests/clipboard/check.cpp" \
    "$sourceDirectory/papi/gui/clipboard/manager.cpp" "$taskDirectory/moc.cpp" \
    "$sourceDirectory/papi/io/transfer/manager.cpp" "$taskDirectory/transfer.cpp" \
    "${flags[@]}" -o "$taskDirectory/check"
QT_QPA_PLATFORM=offscreen "$taskDirectory/check" "$taskDirectory/fixtures"
