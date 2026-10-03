#!/usr/bin/env bash
set -euo pipefail
sourceDirectory=$(cd "$(dirname "$0")/../../.." && pwd)
taskDirectory="$sourceDirectory/build/verification/keyboard"
mkdir -p "$taskDirectory"
/usr/lib/qt6/libexec/moc "$sourceDirectory/papi/display/keyboard/manager.h" -o "$taskDirectory/moc.cpp"
read -r -a flags <<< "$(pkg-config --cflags --libs Qt6Core gio-2.0)"
c++ -std=c++17 -fPIC -I "$sourceDirectory" \
    "$sourceDirectory/gui/tests/keyboard/check.cpp" \
    "$sourceDirectory/papi/display/keyboard/manager.cpp" "$taskDirectory/moc.cpp" \
    "${flags[@]}" -o "$taskDirectory/check"
"$taskDirectory/check"
