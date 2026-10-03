#!/usr/bin/env bash
set -euo pipefail
sourceDirectory=$(cd "$(dirname "$0")/../../.." && pwd)
taskDirectory="$sourceDirectory/build/verification/clipboard"
mkdir -p "$taskDirectory"
/usr/lib/qt6/libexec/moc "$sourceDirectory/papi/gui/clipboard/manager.hpp" -o "$taskDirectory/moc.cpp"
read -r -a flags <<< "$(pkg-config --cflags --libs Qt6Gui Qt6Concurrent)"
c++ -std=c++17 -fPIC -I "$sourceDirectory/build/papi/include" \
    "$sourceDirectory/gui/tests/clipboard/check.cpp" \
    "$sourceDirectory/papi/gui/clipboard/manager.cpp" "$taskDirectory/moc.cpp" \
    "${flags[@]}" -o "$taskDirectory/check"
QT_QPA_PLATFORM=offscreen "$taskDirectory/check" "$taskDirectory/fixtures"
