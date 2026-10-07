#!/usr/bin/env python3
"""Check conditional window-width restoration when Information closes."""
import os
from pathlib import Path
import shutil
import subprocess

root = Path(__file__).resolve().parents[3]
target = root / 'build/verification/files/information'
target.mkdir(parents=True, exist_ok=True)
fixtures = target / 'fixtures'
fixtures.mkdir(exist_ok=True)
(fixtures / 'file.txt').write_text('Information width fixture\n')
for name in ('qml', 'assets'):
    link = target / name
    if not link.exists():
        link.symlink_to(root / 'gui' / name, target_is_directory=True)
shutil.copytree(root / 'gui/config', target / 'config', dirs_exist_ok=True)
source = (root / 'gui/Main.qml').read_text()
probe = r'''
    property var informationWindow: null
    Timer {
        interval: 300; running: true; repeat: true
        property int step: 0
        property int ticks: 0
        property real original: 0
        property real chosen: 0
        property real expanded: 0
        onTriggered: {
            if (++ticks > 90) { console.error("WIDTH_FAILED timeout", step); Qt.exit(1); return; }
            if (step === 0) {
                const loader = main.openFolderWindow("@FIXTURES@");
                if (!loader.item) return;
                informationWindow = loader.item;
            } else {
                const browser = informationWindow.contentItem;
                const controller = informationWindow.controller;
                if (controller.directory.loading) return;
                if (step === 1) {
                    original = informationWindow.width;
                    controller.informationRequested(controller.files[0]);
                } else if (step === 2) {
                    if (browser.originalInformationWidth !== original || informationWindow.width < original) { console.error("WIDTH_FAILED expansion tracking"); Qt.exit(1); return; }
                    browser.informationEntry = null;
                } else if (step === 3) {
                    if (Math.abs(informationWindow.width - original) > 1) { console.error("WIDTH_FAILED original must restore"); Qt.exit(1); return; }
                    controller.informationRequested(controller.files[0]);
                } else if (step === 4) {
                    chosen = informationWindow.width - 20;
                    informationWindow.width = chosen;
                } else if (step === 5) {
                    browser.informationEntry = null;
                } else if (step === 6) {
                    if (Math.abs(informationWindow.width - chosen) > 1) { console.error("WIDTH_FAILED user width must stay"); Qt.exit(1); return; }
                    controller.informationRequested(controller.files[0]);
                } else if (step === 7) {
                    expanded = informationWindow.width;
                    informationWindow.width = expanded - 15;
                    informationWindow.width = expanded;
                    browser.informationEntry = null;
                } else if (step === 8) {
                    if (Math.abs(informationWindow.width - expanded) > 1) { console.error("WIDTH_FAILED resize history must stay remembered"); Qt.exit(1); return; }
                    console.log("WIDTH_PASSED original restore, user resize and resize-back preservation");
                    Qt.quit();
                }
            }
            ++step;
        }
    }
'''.replace('@FIXTURES@', fixtures.as_uri())
position = source.rfind('}')
(target / 'Main.qml').write_text(source[:position] + probe + source[position:])
environment = dict(os.environ, PEDRO_DEVELOPMENT_MODE='1', PEDRO_QML_DIR=str(target),
                   XDG_DATA_HOME=str(target / 'data'),
                   QT_QPA_PLATFORM=os.environ.get('PEDRO_TEST_PLATFORM', 'offscreen'),
                   QT_QUICK_BACKEND=os.environ.get('QT_QUICK_BACKEND', 'software'), QT_QPA_PLATFORMTHEME='none')
result = subprocess.run([str(root / 'build/dev/gui/pedro-gui')], env=environment, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=45)
(target / 'check.log').write_text(result.stdout)
if result.returncode or 'WIDTH_PASSED' not in result.stdout or any(value in result.stdout for value in ('WIDTH_FAILED', 'TypeError', 'ReferenceError', 'Binding loop')):
    raise SystemExit(result.stdout)
print('PASS: conditional Information window-width restoration')
