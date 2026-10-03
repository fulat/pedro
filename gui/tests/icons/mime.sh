#!/usr/bin/env bash
set -euo pipefail
sourceDirectory=$(cd "$(dirname "$0")/../../.." && pwd)
taskDirectory="$sourceDirectory/build/verification/mime"
mkdir -p "$taskDirectory/config"
python3 - "$taskDirectory" <<'PY'
from pathlib import Path
import sys
root = Path(sys.argv[1])
(root / 'config/user-dirs.dirs').write_text(f'XDG_DESKTOP_DIR="{root}/desktop"\n')
PY
/usr/lib/qt6/libexec/moc "$sourceDirectory/papi/io/directory/model.hpp" -o "$taskDirectory/directory.cpp"
/usr/lib/qt6/libexec/moc "$sourceDirectory/papi/io/desktop/model.hpp" -o "$taskDirectory/desktop.cpp"
read -r -a flags <<< "$(pkg-config --cflags --libs Qt6Quick Qt6Svg Qt6Concurrent gio-2.0 gio-unix-2.0)"
c++ -std=c++17 -fPIC -I "$sourceDirectory/build/dev/papi/include" \
    "$sourceDirectory/gui/tests/icons/mime.cpp" \
    "$sourceDirectory/papi/io/content/icon.cpp" \
    "$sourceDirectory/papi/io/directory/model.cpp" \
    "$sourceDirectory/papi/io/desktop/model.cpp" \
    "$taskDirectory/directory.cpp" "$taskDirectory/desktop.cpp" \
    "${flags[@]}" -o "$taskDirectory/check"
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_QPA_PLATFORMTHEME=none \
    XDG_CONFIG_HOME="$taskDirectory/config" "$taskDirectory/check" "$taskDirectory" "$sourceDirectory"
