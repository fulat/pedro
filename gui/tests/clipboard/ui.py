#!/usr/bin/env python3
"""Verify shared Desktop/Files clipboard dispatch offscreen with build fixtures."""
import json
import os
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[3]
target = root / 'build/verification/clipboard/ui'
target.mkdir(parents=True, exist_ok=True)
fixtures = target / 'fixtures'
import shutil
if fixtures.exists():
    shutil.rmtree(fixtures)
for directory in ('source', 'destination'):
    (fixtures / directory).mkdir(parents=True)
(fixtures / 'source' / 'shared.txt').write_text('shared clipboard fixture\n')
for name in ('qml', 'config', 'assets'):
    link = target / name
    if not link.exists():
        link.symlink_to(root / 'gui' / name, target_is_directory=True)
source = (root / 'gui/Main.qml').read_text().replace('import QtQuick', 'import gui\nimport QtQuick', 1)
actions = '''
    property QtObject transferProbe: QtObject {
        property bool busy: false
        property real progress: 0.55
        property string currentFile: "Fixture.bin"
        property string error: ""
        property bool cancelled: false
        signal changed()
        function cancel() { cancelled = true; busy = false; changed(); }
        function dismissError() { error = ""; changed(); }
    }
    function clipboardControl(item, name) {
        if (item.objectName === name) return item;
        for (const child of item.children || []) {
            const result = clipboardControl(child, name);
            if (result) return result;
        }
        return null;
    }
    Timer {
        interval: 200
        running: true
        repeat: true
        property int step: 0
        property int ticks: 0
        property var panel: null
        onTriggered: {
            if (++ticks > 100) { console.error("CLIPBOARD UI FAILED: timeout"); Qt.exit(1); return; }
            if (Backend.fileTransfer.error.length && !Backend.fileTransfer.cancelled) {
                console.error("CLIPBOARD UI FAILED", Backend.fileTransfer.error); Qt.exit(1); return;
            }
            if (step === 0) {
                if (Backend.clipboard.operation !== Backend.fileTransfer) {
                    console.error("CLIPBOARD UI FAILED: duplicate transfer engines"); Qt.exit(1); return;
                }
                main.controller.openTrashQuickWindow();
                ++step;
                return;
            }
            const window = main.controller.filesQuickWindow;
            if (!window.controller) return;
            const controller = window.controller;
            if (Backend.fileTransfer.busy || controller.directory.loading) return;
            if (step === 1) {
                controller.directory.open(DESTINATION);
            } else if (step === 2) {
                // Exercise the real Desktop dispatcher with a fixture selection.
                const original = main.controller.desktopShortcutRepeater;
                const entry = {id: SOURCE_FILE, url: SOURCE_FILE, name: "shared.txt", isDirectory: false};
                main.controller.desktopShortcutRepeater = {count: 1, itemAt: function(index) { return {app: entry}; }};
                main.controller.entryAction("copy", entry);
                main.controller.desktopShortcutRepeater = original;
                const menu = window.contentItem.backgroundContextMenu;
                menu.directory = controller.directory;
                const paste = main.clipboardControl(menu.contentItem, "filesPaste");
                if (!paste || !paste.enabled || !Backend.clipboard.canPaste) {
                    console.error("CLIPBOARD UI FAILED: folder paste unavailable"); Qt.exit(1); return;
                }
                paste.triggered();
            } else if (step === 3) {
                const entry = controller.files.find(entry => entry.name === "shared.txt");
                if (!entry) return;
                controller.entryAction("cut", entry);
                // Paste through the Desktop dispatcher into a different folder.
                main.controller.entryAction("paste", {isDirectory: true, url: SOURCE_FOLDER});
            } else if (step === 4) {
                if (controller.files.some(entry => entry.name === "shared.txt")) return;
                if (Backend.clipboard.canPaste) {
                    console.error("CLIPBOARD UI FAILED: cut clipboard not cleared"); Qt.exit(1); return;
                }
                const component = Qt.createComponent("qml/components/transfer/window.qml");
                panel = component.createObject(main, {operation: main.transferProbe, ownerWindow: main});
                if (!panel) { console.error("CLIPBOARD UI FAILED", component.errorString()); Qt.exit(1); return; }
                main.transferProbe.busy = true;
                main.transferProbe.changed();
            } else if (step === 5) {
                if (!panel.visible) return;
                if (panel.progress !== 0.55 || panel.blocking || panel.message !== "Fixture.bin") {
                    console.error("CLIPBOARD UI FAILED: progress panel"); Qt.exit(1); return;
                }
                panel.accept();
                if (!main.transferProbe.cancelled || panel.visible) {
                    console.error("CLIPBOARD UI FAILED: progress cancel"); Qt.exit(1); return;
                }
                panel.destroy();
                console.log("CLIPBOARD UI PASSED: Desktop/Files interoperability, folder paste and cancelable Liquid progress");
                Qt.quit();
            }
            ++step;
        }
    }
'''
for key, value in {'DESTINATION': (fixtures / 'destination').as_uri(), 'SOURCE_FILE': (fixtures / 'source' / 'shared.txt').as_uri(), 'SOURCE_FOLDER': (fixtures / 'source').as_uri()}.items():
    actions = actions.replace(key, json.dumps(value))
position = source.rfind('}')
(target / 'Main.qml').write_text(source[:position] + actions + source[position:])
environment = dict(os.environ, PEDRO_DEVELOPMENT_MODE='1', PEDRO_QML_DIR=str(target),
                   QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software', QT_QPA_PLATFORMTHEME='none')
result = subprocess.run([str(root / 'build/dev/gui/pedro-gui')], env=environment,
                        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=35)
(target / 'check.log').write_text(result.stdout)
if result.returncode or 'CLIPBOARD UI PASSED' not in result.stdout or any(error in result.stdout for error in ('ReferenceError', 'TypeError', 'CLIPBOARD UI FAILED')):
    raise SystemExit(result.stdout)
assert (fixtures / 'source' / 'shared (2).txt').read_text() == 'shared clipboard fixture\n'
print('PASS: shared Desktop and Files clipboard workflow')
