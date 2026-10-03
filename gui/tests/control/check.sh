#!/usr/bin/env bash
set -euo pipefail
sourceDirectory=$(cd "$(dirname "$0")/../../.." && pwd)
taskDirectory="$sourceDirectory/build/verification/control"
mkdir -p "$taskDirectory"
/usr/lib/qt6/libexec/moc "$sourceDirectory/papi/power/profile/manager.h" -o "$taskDirectory/profile.cpp"
/usr/lib/qt6/libexec/moc "$sourceDirectory/papi/gui/focus/manager.h" -o "$taskDirectory/focus.cpp"
read -r -a flags <<< "$(pkg-config --cflags --libs Qt6Core Qt6DBus gio-2.0)"
c++ -std=c++17 -fPIC -I "$sourceDirectory" \
    "$sourceDirectory/gui/tests/control/check.cpp" \
    "$sourceDirectory/papi/power/profile/manager.cpp" "$taskDirectory/profile.cpp" \
    "$sourceDirectory/papi/gui/focus/manager.cpp" "$taskDirectory/focus.cpp" \
    "${flags[@]}" -o "$taskDirectory/check"
"$taskDirectory/check"
