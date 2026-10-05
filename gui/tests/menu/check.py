#!/usr/bin/env python3
"""Exercise Pedro's native menu windows; keep generated fixtures under build/."""
import os
from pathlib import Path
import selectors
import subprocess
import time

root = Path(__file__).resolve().parents[3]
target = root / 'build/verification/menu'
target.mkdir(parents=True, exist_ok=True)
for name in ('qml', 'config', 'assets'):
    link = target / name
    if not link.exists():
        link.symlink_to(root / 'gui' / name, target_is_directory=True)
# Wayland dismisses programmatic popup grabs without a real input serial.
# Check protocol survival there; use X11 to also assert persistent visibility.
require_visible = os.environ.get('QT_QPA_PLATFORM') != 'wayland' and (os.environ.get('QT_QPA_PLATFORM') == 'xcb' or os.environ.get('XDG_SESSION_TYPE') != 'wayland')
source = (root / 'gui/Main.qml').read_text().replace('import QtQuick', 'import gui\nimport QtQuick', 1)
position = source.rfind('}')
actions = '''
    Timer {
        interval: 250
        running: true
        repeat: true
        property int step: 0
        property var modes: ["battery", "", "system", "", "battery", "quick", "", "wifi", "", "battery", "", "system", ""]
        onTriggered: {
            if (step === 0 && (Backend !== Papi || Backend.audioVolume !== Papi.audioVolume || Backend.capture !== Papi.capture)) {
                console.error("MENU CHECK FAILED: duplicate PAPI backend");
                running = false;
                return;
            }
            if (REQUIRE_VISIBLE && step > 0 && modes[(step - 1) % modes.length] && (!panelPopup.visible || panelPopup.width <= 0 || panelPopup.height <= 0)) {
                console.error("MENU CHECK FAILED", step, modes[(step - 1) % modes.length], main.panelMode, panelPopup.visible, panelPopup.width, panelPopup.height);
                running = false;
                return;
            }
            const mode = modes[step % modes.length];
            if (mode) main.controller.togglePanel(mode, main.width - 200, mode);
            else main.controller.closePanel();
            if (++step >= 52) {
                running = false;
                console.log("MENU CHECK PASSED: 52 native popup transitions");
            }
        }
    }
'''
actions = actions.replace('REQUIRE_VISIBLE', 'true' if require_visible else 'false')
(target / 'Main.qml').write_text(source[:position] + actions + source[position:])
environment = dict(os.environ, PEDRO_DEVELOPMENT_MODE='1', PEDRO_QML_DIR=str(target))
executable = Path(os.environ.get('PEDRO_GUI_EXECUTABLE', str(root / 'build/dev/gui/pedro-gui')))
process = subprocess.Popen([str(executable)], env=environment, stdout=subprocess.PIPE,
                           stderr=subprocess.STDOUT)
selector = selectors.DefaultSelector()
selector.register(process.stdout, selectors.EVENT_READ)
passed = False
try:
    deadline = time.monotonic() + 30
    with (target / 'check.log').open('w') as log:
        while time.monotonic() < deadline and process.poll() is None:
            for key, _ in selector.select(0.2):
                line = os.read(key.fileobj.fileno(), 65536).decode(errors='replace')
                log.write(line)
                log.flush()
                if any(error in line for error in ('Invalid size', 'fatal error', 'ReferenceError', 'Error decoding', 'Error:', 'MENU CHECK FAILED')):
                    raise RuntimeError(line.strip())
                if 'MENU CHECK PASSED' in line:
                    passed = True
            if passed:
                time.sleep(0.5)
                if process.poll() is not None:
                    raise RuntimeError('Pedro exited after opening its menus')
                break
    if not passed:
        raise RuntimeError(f'Menu check did not complete; see {target / "check.log"}')
    print('Battery, system, quick controls and Wi-Fi: 52 popup transitions passed without a Wayland disconnect')
finally:
    selector.close()
    if process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
