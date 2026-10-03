#!/usr/bin/env bash
set -euo pipefail

sourceDirectory=$(cd "$(dirname "$0")/../../.." && pwd)
taskDirectory="$sourceDirectory/build/verification/sort"
mkdir -p "$taskDirectory/config" "$taskDirectory/desktop"

python3 - "$taskDirectory" <<'PY'
from pathlib import Path
import os
import sys
root = Path(sys.argv[1])
(root / 'config/user-dirs.dirs').write_text(f'XDG_DESKTOP_DIR="{root}/desktop"\n')
(root / 'desktop/new.txt').unlink(missing_ok=True)
for index, (name, size) in enumerate([('Alpha.txt', 10), ('Beta.svg', 100), ('node2.txt', 30), ('node10.txt', 200)]):
    path = root / 'desktop' / name
    path.write_text('x' * size)
    os.utime(path, (1000000000 + index * 100, 1000000000 + index * 100))
(root / 'desktop/Folder').mkdir(exist_ok=True)
PY

# Compile standalone checks using the public includes from the development build.
/usr/lib/qt6/libexec/moc "$sourceDirectory/papi/io/desktop/model.hpp" -o "$taskDirectory/moc.cpp"
commonSources=("$sourceDirectory/papi/io/desktop/model.cpp" "$taskDirectory/moc.cpp")
read -r -a modelFlags <<< "$(pkg-config --cflags --libs Qt6Core Qt6Test gio-2.0 gio-unix-2.0)"
read -r -a viewFlags <<< "$(pkg-config --cflags --libs Qt6Quick Qt6Qml gio-2.0 gio-unix-2.0)"
c++ -std=c++17 -fPIC -I "$sourceDirectory/build/papi/include" \
    "$sourceDirectory/gui/tests/desktop/model.cpp" "${commonSources[@]}" "${modelFlags[@]}" -o "$taskDirectory/check"
c++ -std=c++17 -fPIC -I "$sourceDirectory/build/papi/include" \
    "$sourceDirectory/gui/tests/desktop/view.cpp" "${commonSources[@]}" "${viewFlags[@]}" -o "$taskDirectory/view"

XDG_CONFIG_HOME="$taskDirectory/config" "$taskDirectory/check"
QT_QPA_PLATFORM=offscreen XDG_CONFIG_HOME="$taskDirectory/config" \
    "$taskDirectory/view" "$sourceDirectory/gui/tests/desktop/View.qml"
