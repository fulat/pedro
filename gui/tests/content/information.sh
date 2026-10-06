#!/usr/bin/env bash
set -euo pipefail
sourceDirectory=$(cd "$(dirname "$0")/../../.." && pwd)
taskDirectory="$sourceDirectory/build/verification/content/information"
mkdir -p "$taskDirectory"
/usr/lib/qt6/libexec/moc "$sourceDirectory/papi/io/file/information.h" -o "$taskDirectory/information.cpp"
/usr/lib/qt6/libexec/moc "$sourceDirectory/papi/io/file/watch.h" -o "$taskDirectory/watch.cpp"
read -r -a flags <<< "$(pkg-config --cflags --libs Qt6Core Qt6Concurrent Qt6Test gio-2.0)"
c++ -std=c++17 -fPIC -I "$sourceDirectory/build/dev/papi/include" \
    "$sourceDirectory/gui/tests/content/information.cpp" \
    "$sourceDirectory/papi/io/file/information.cpp" "$sourceDirectory/papi/io/file/watch.cpp" \
    "$taskDirectory/information.cpp" "$taskDirectory/watch.cpp" "${flags[@]}" -o "$taskDirectory/check"
"$taskDirectory/check" "$taskDirectory/file.txt"
