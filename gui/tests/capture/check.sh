#!/usr/bin/env bash
set -euo pipefail
sourceDirectory=$(cd "$(dirname "$0")/../../.." && pwd)
taskDirectory="$sourceDirectory/build/verification/capture"
mkdir -p "$taskDirectory"
/usr/lib/qt6/libexec/moc "$sourceDirectory/papi/gui/capture/manager.h" -o "$taskDirectory/moc.cpp"
/usr/lib/qt6/libexec/moc "$sourceDirectory/gui/tests/capture/check.cpp" -o "$taskDirectory/check.moc"
read -r -a flags <<< "$(pkg-config --cflags --libs Qt6Core Qt6DBus)"
c++ -std=c++17 -fPIC -I "$sourceDirectory" -I "$taskDirectory" \
    "$sourceDirectory/gui/tests/capture/check.cpp" \
    "$sourceDirectory/papi/gui/capture/manager.cpp" "$taskDirectory/moc.cpp" \
    "${flags[@]}" -o "$taskDirectory/check"
# Never opens the real capture UI or changes the user's session.
dbus-run-session -- "$taskDirectory/check"
