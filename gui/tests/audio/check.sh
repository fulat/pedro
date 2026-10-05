#!/usr/bin/env bash
set -euo pipefail
sourceDirectory=$(cd "$(dirname "$0")/../../.." && pwd)
taskDirectory="$sourceDirectory/build/verification/audio"
mkdir -p "$taskDirectory/bin"
python3 - "$taskDirectory" <<'PY'
from pathlib import Path
import sys
root = Path(sys.argv[1])
(root / 'queries').write_text('')
(root / 'volume').write_text('Volume: 0.97\n')
(root / 'bin/wpctl').write_text('''#!/usr/bin/python3
from pathlib import Path
import os
root = Path(os.environ['PEDRO_AUDIO_FIXTURE'])
with (root / 'queries').open('a') as output: output.write('read\\n')
print((root / 'volume').read_text())
''')
(root / 'bin/pw-dump').write_text('''#!/usr/bin/python3
from pathlib import Path
import json, os, time
root = Path(os.environ['PEDRO_AUDIO_FIXTURE'])
def event(value): print(json.dumps([value]), flush=True)
record = json.dumps([{'id': 30, 'type': 'PipeWire:Interface:Node', 'info': {'props': {'node.name': 'Output [speaker]'}}}])
print(record[:40], end='', flush=True)
time.sleep(.04)
print(record[40:], flush=True)
for index in range(20):
    event({'id': 100 + index, 'type': 'PipeWire:Interface:Client', 'info': {'props': {'application.name': 'wpctl'}}})
    event({'id': 100 + index, 'info': None})
    time.sleep(.015)
(root / 'volume').write_text('Volume: 0.75\\n')
event({'id': 30, 'info': {'params': {'Props': [{'volume': .75}]}}})
time.sleep(.3)
(root / 'volume').write_text('Volume: 0.42 [MUTED]\\n')
event({'id': 7, 'type': 'PipeWire:Interface:Metadata', 'metadata': [{'key': 'default.audio.sink', 'value': 'Other speaker'}]})
time.sleep(3)
''')
for path in (root / 'bin').iterdir(): path.chmod(0o755)
PY
/usr/lib/qt6/libexec/moc "$sourceDirectory/papi/audio/volume/manager.h" -o "$taskDirectory/moc.cpp"
read -r -a flags <<< "$(pkg-config --cflags --libs Qt6Core)"
c++ -std=c++17 -fPIC -I "$sourceDirectory/build/dev/papi/include" \
    "$sourceDirectory/gui/tests/audio/check.cpp" "$sourceDirectory/papi/audio/volume/manager.cpp" \
    "$taskDirectory/moc.cpp" "${flags[@]}" -o "$taskDirectory/check"
PEDRO_AUDIO_FIXTURE="$taskDirectory" PATH="$taskDirectory/bin:$PATH" "$taskDirectory/check" "$taskDirectory"
