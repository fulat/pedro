#!/usr/bin/env python3
"""Exercise actual Pedro restoration in GNOME/Wayland; generate probes under build/."""
from pathlib import Path
import os
import shlex
import subprocess

root = Path(__file__).resolve().parents[3]
dev = root / 'build/dev'
target = root / 'build/verification/restore'
target.mkdir(parents=True, exist_ok=True)
interface = subprocess.check_output(['gdbus', 'introspect', '--session', '--dest',
    'org.pedro.Applications', '--object-path', '/org/pedro/Applications'], text=True)
if 'ActivateWindowIdentity' not in interface or 'PlaceWindowIdentity' not in interface:
    raise SystemExit('Load the current Pedro GNOME extension before running this native check.')
for name in ('config', 'assets', 'qml'):
    link = target / name
    if not link.exists():
        link.symlink_to(root / 'gui' / name, target_is_directory=True)
for name in ('one', 'two'):
    folder = target / name
    folder.mkdir(exist_ok=True)
    (folder / 'note.txt').write_text(name + '\n')
qml = (root / 'gui/tests/window/restore.qml').read_text()
qml = qml.replace('@COMPONENTS@', (root / 'gui/qml/components').as_uri())
qml = qml.replace('@ONE@', (target / 'one/note.txt').as_uri())
qml = qml.replace('@TWO@', (target / 'two/note.txt').as_uri())
(target / 'Main.qml').write_text(qml)
# Keep all production backend/providers and replace only the entry object with
# a focus probe. QWindow::active includes related transient windows; it is not
# sufficient to identify which native window actually received keyboard focus.
source = (root / 'gui/backend/main.cpp').read_text()
source = source.replace('#include <QQmlContext>', '#include <QQmlContext>\n#include <QQmlPropertyMap>')
source = source.replace('    QQmlApplicationEngine engine;', '''    QQmlApplicationEngine engine;
    QQmlPropertyMap diagnostic;
    engine.rootContext()->setContextProperty("Diagnostic", &diagnostic);
    QTimer focusProbe;
    focusProbe.setInterval(20);
    QObject::connect(&focusProbe, &QTimer::timeout, &engine, [&] {
        diagnostic.insert("focusedWindow", QVariant::fromValue<QObject*>(QGuiApplication::focusWindow()));
    });
    focusProbe.start();''')
(target / 'main.cpp').write_text(source)
commands = subprocess.check_output(['ninja', '-t', 'commands', 'gui/pedro-gui'], cwd=dev, text=True).splitlines()
compile_line = next(line for line in commands if ' -c ' + str(root / 'gui/backend/main.cpp') in line)
args = shlex.split(compile_line)
args[args.index('-o') + 1] = str(target / 'main.o')
args[args.index('-c') + 1] = str(target / 'main.cpp')
if '-MF' in args:
    args[args.index('-MF') + 1] = str(target / 'main.d')
args.append('-I' + str(root / 'gui/backend'))
subprocess.run(args, cwd=dev, check=True)
link_line = next(line for line in commands if ' -o gui/pedro-gui ' in line)
args = shlex.split(next(part for part in link_line.split(' && ') if ' -o gui/pedro-gui ' in part))
args[args.index('-o') + 1] = str(target / 'check')
args = [str(target / 'main.o') if arg == 'gui/CMakeFiles/pedro_gui.dir/backend/main.cpp.o' else arg for arg in args]
subprocess.run(args, cwd=dev, check=True)
environment = dict(os.environ, PEDRO_DEVELOPMENT_MODE='1', PEDRO_QML_DIR=str(target), QT_QPA_PLATFORM='wayland')
with (target / 'check.log').open('w') as log:
    result = subprocess.run([str(target / 'check')], env=environment, stdout=log, stderr=subprocess.STDOUT, timeout=45)
output = (target / 'check.log').read_text()
if result.returncode != 0 or 'RESTORE SUMMARY 40 failures 0' not in output or 'ReferenceError' in output:
    raise SystemExit('Native restoration failed; see ' + str(target / 'check.log'))
print('PASS: 30 immediate minimize/reopen cycles and 10 superseding opens with exact native focus')
