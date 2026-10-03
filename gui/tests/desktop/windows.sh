#!/usr/bin/env bash
set -euo pipefail
sourceDirectory=$(cd "$(dirname "$0")/../../.." && pwd)
taskDirectory="$sourceDirectory/build/verification/windows"
mkdir -p "$taskDirectory"
python3 - "$sourceDirectory" "$taskDirectory" <<'PY'
from pathlib import Path
import sys
source = Path(sys.argv[1])
target = Path(sys.argv[2])
qml = (source / 'gui/tests/desktop/windows.qml').read_text()
qml = qml.replace('../../qml/components', (source / 'gui/qml/components').as_uri())
(target / 'Main.qml').write_text(qml)
PY
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software PEDRO_QML_DIR="$taskDirectory" \
    timeout 10 "$sourceDirectory/build/gui/pedro-gui"
