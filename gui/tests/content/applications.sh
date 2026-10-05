#!/usr/bin/env bash
set -euo pipefail
sourceDirectory=$(cd "$(dirname "$0")/../../.." && pwd)
taskDirectory="$sourceDirectory/build/verification/content/applications"
mkdir -p "$taskDirectory/data/applications" "$taskDirectory/config" "$taskDirectory/cache"
python3 - "$taskDirectory" <<'PY'
from pathlib import Path
import sys
root = Path(sys.argv[1])
(root / 'launched.txt').unlink(missing_ok=True)
(root / 'a file; quoted.txt').write_text('Plain text application fixture\n')
(root / 'record.py').write_text('from pathlib import Path\nimport sys\nPath(sys.argv[1]).write_text(sys.argv[2])\n')
(root / 'missing-handler').write_text('#!/bin/sh\nexit 0\n')
(root / 'missing-handler').chmod(0o755)
for name, hidden in [('fixture', False), ('hidden', True), ('broken', False)]:
    command = f'Exec="{root}/missing-handler" %u\n' if name == 'broken' else f'Exec=/usr/bin/python3 "{root}/record.py" "{root}/launched.txt" %u\n'
    (root / 'data/applications' / f'pedro-{name}.desktop').write_text(
        '[Desktop Entry]\nType=Application\nName=Pedro test handler\n' + command +
        f'MimeType=text/plain;\nIcon=text-editor\nNoDisplay={str(hidden).lower()}\n')
(root / 'config/mimeapps.list').write_text('[Default Applications]\ntext/plain=pedro-fixture.desktop;\n')
PY
update-desktop-database "$taskDirectory/data/applications"
/usr/lib/qt6/libexec/moc "$sourceDirectory/papi/io/content/applications.hpp" -o "$taskDirectory/moc.cpp"
read -r -a flags <<< "$(pkg-config --cflags --libs Qt6Core Qt6Concurrent Qt6Test gio-2.0 gio-unix-2.0)"
c++ -std=c++17 -fPIC -I "$sourceDirectory/build/dev/papi/include" \
    "$sourceDirectory/gui/tests/content/applications.cpp" \
    "$sourceDirectory/papi/io/content/applications.cpp" "$taskDirectory/moc.cpp" \
    "${flags[@]}" -o "$taskDirectory/check"
XDG_DATA_HOME="$taskDirectory/data" XDG_CONFIG_HOME="$taskDirectory/config" \
    XDG_CACHE_HOME="$taskDirectory/cache" XDG_DATA_DIRS=/usr/share \
    "$taskDirectory/check" "$taskDirectory/a file; quoted.txt" "$taskDirectory/launched.txt"
