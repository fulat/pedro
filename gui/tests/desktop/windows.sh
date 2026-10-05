#!/usr/bin/env bash
set -euo pipefail
sourceDirectory=$(cd "$(dirname "$0")/../../.." && pwd)
taskDirectory="$sourceDirectory/build/verification/windows"
mkdir -p "$taskDirectory"
ln -sfn "$sourceDirectory/gui/assets" "$taskDirectory/assets"
python3 - "$sourceDirectory" "$taskDirectory" <<'PY'
from pathlib import Path
import sys
source = Path(sys.argv[1])
target = Path(sys.argv[2])
qml = (source / 'gui/tests/desktop/windows.qml').read_text()
qml = qml.replace('../../qml/components', (source / 'gui/qml/components').as_uri())
(target / 'Main.qml').write_text(qml)
PY
python3 - "$sourceDirectory" "$taskDirectory" <<'PYTEST'
import os
from pathlib import Path
import subprocess
import sys
source, target = map(Path, sys.argv[1:])
environment = dict(os.environ, PEDRO_DEVELOPMENT_MODE='1', QT_QPA_PLATFORMTHEME='none',
                   QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software', PEDRO_QML_DIR=str(target))
process = subprocess.Popen([str(source / 'build/dev/gui/pedro-gui')], env=environment,
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
try:
    output, _ = process.communicate(timeout=10)
except subprocess.TimeoutExpired:
    process.terminate()
    output, _ = process.communicate(timeout=5)
(target / 'check.log').write_text(output)
assert 'three distinct windows with reserved separate positions passed' in output, output
assert not any(error in output for error in ('failed', 'ReferenceError', 'TypeError',
               'Binding loop detected', 'Failed to get image from provider')), output
print('PASS: independent folder windows, separate positions and duplicate suppression')
PYTEST
