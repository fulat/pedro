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
        if (item.objectName === name && (!name.startsWith("entryComponent-") || item.visible)) return item;
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
        property var standaloneFile: null
        property var standaloneFolder: null
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
            } else if (step === 4) {
                const item = main.clipboardControl(window.contentItem, "entryComponent-shared.txt");
                if (!item) return;
                const icon = item.children.find(child => child.kind !== undefined);
                const badge = item.children.find(child => child.objectName === "cutBadge");
                if (!badge || !badge.visible || badge.opacity >= 1 || badge.anchors.centerIn !== icon) {
                    console.error("CLIPBOARD UI FAILED: missing cut scissors"); Qt.exit(1); return;
                }
                if (!item.cutPending || !icon || icon.opacity >= 1 || !item.enabled || item.opacity !== 1) {
                    console.error("CLIPBOARD UI FAILED: cut must dim only visuals"); Qt.exit(1); return;
                }
                Backend.clipboard.copy([controller.files[0].url]);
                if (item.cutPending || icon.opacity !== 1) {
                    console.error("CLIPBOARD UI FAILED: copy must restore opacity"); Qt.exit(1); return;
                }
                controller.entryAction("cut", controller.files[0]);
                // Paste through the Desktop dispatcher into a different folder.
                main.controller.entryAction("paste", {isDirectory: true, url: SOURCE_FOLDER});
            } else if (step === 5) {
                if (controller.files.some(entry => entry.name === "shared.txt")) return;
                if (Backend.clipboard.canPaste) {
                    console.error("CLIPBOARD UI FAILED: cut clipboard not cleared"); Qt.exit(1); return;
                }
                const component = Qt.createComponent("qml/components/transfer/window.qml");
                panel = component.createObject(main, {operation: main.transferProbe, ownerWindow: main});
                if (!panel) { console.error("CLIPBOARD UI FAILED", component.errorString()); Qt.exit(1); return; }
                main.transferProbe.busy = true;
                main.transferProbe.changed();
            } else if (step === 6) {
                if (!panel.visible) return;
                if (panel.progress !== 0.55 || panel.blocking || panel.message !== "Fixture.bin") {
                    console.error("CLIPBOARD UI FAILED: progress panel"); Qt.exit(1); return;
                }
                panel.accept();
                if (!main.transferProbe.cancelled || panel.visible) {
                    console.error("CLIPBOARD UI FAILED: progress cancel"); Qt.exit(1); return;
                }
                panel.destroy();
                const fileComponent = Qt.createComponent("qml/components/entry/file.qml");
                const folderComponent = Qt.createComponent("qml/components/entry/folder.qml");
                standaloneFile = fileComponent.createObject(main.contentItem, {entry: {name: "shared.txt", url: SOURCE_FILE}, width: 90, height: 100});
                standaloneFolder = folderComponent.createObject(main.contentItem, {entry: {name: "destination", url: DESTINATION}, width: 90, height: 100});
                if (!standaloneFile || !standaloneFolder) { console.error("CLIPBOARD UI FAILED: standalone components"); Qt.exit(1); return; }
                standaloneFile.dispatch("rename");
                if (!standaloneFile.renaming || !standaloneFile.nameEditor.visible) { console.error("CLIPBOARD UI FAILED: standalone inline rename"); Qt.exit(1); return; }
                standaloneFile.item.cancelRename();
                standaloneFile.dispatch("cut");
                if (!standaloneFile.cutPending || !standaloneFolder.canDrop([SOURCE_FILE]) || standaloneFolder.canDrop([DESTINATION])) {
                    console.error("CLIPBOARD UI FAILED: behavior requires a host controller"); Qt.exit(1); return;
                }
                standaloneFile.dispatch("copy");
                standaloneFile.openMenu(10, 10);
                if (standaloneFile.cutPending || !standaloneFile.item.menu.visible) { console.error("CLIPBOARD UI FAILED: standalone menu"); Qt.exit(1); return; }
                standaloneFile.closeMenu();
                if (!standaloneFolder.dropFiles([SOURCE_FILE])) { console.error("CLIPBOARD UI FAILED: standalone folder drop"); Qt.exit(1); return; }
            } else if (step === 7) {
                if (Backend.fileTransfer.busy) return;
                standaloneFile.destroy();
                standaloneFolder.destroy();
                controller.directory.open(DESTINATION);
                controller.viewMode = "list";
            } else if (step === 8 || step === 9 || step === 10 || step === 11) {
                const item = main.clipboardControl(window.contentItem, "entryComponent-shared.txt");
                if (!item) return;
                if ((step === 8 || step === 9) && item.inputSurface.width <= item.iconSize) {
                    console.error("CLIPBOARD UI FAILED: row does not use shared interaction surface"); Qt.exit(1); return;
                }
                item.dispatch("cut");
                item.openMenu(10, 10);
                if (!item.menu.visible || item.menu.canCut || !item.cutPending) { console.error("CLIPBOARD UI FAILED: view behavior differs"); Qt.exit(1); return; }
                item.menu.close();
                item.dispatch("copy");
                item.dispatch("rename");
                if (!item.renaming || !item.nameEditor.visible || item.nameEditor.Window.window !== window) { console.error("CLIPBOARD UI FAILED: inline editor missing from view", step); Qt.exit(1); return; }
                item.cancelRename();
                if (step === 8) controller.viewMode = "columns";
                else if (step === 9) controller.viewMode = "grid";
                else if (step === 10) controller.viewMode = "mixed";
                else {
                    const entry = controller.files.find(entry => entry.name === "shared.txt");
                    controller.entryAction("rename", entry);
                }
            } else if (step === 12) {
                const item = main.clipboardControl(window.contentItem, "entryComponent-shared.txt");
                if (!item || !item.renaming || !item.nameEditor.visible) { console.error("CLIPBOARD UI FAILED: inline rename"); Qt.exit(1); return; }
                item.nameEditor.text = "../bad";
                item.finishRename();
                if (!item.renaming) { console.error("CLIPBOARD UI FAILED: invalid name accepted"); Qt.exit(1); return; }
                item.nameEditor.text = "renamed fixture.txt";
                item.nameEditor.accepted();
            } else if (step === 13) {
                const entry = controller.files.find(entry => entry.name === "renamed fixture.txt");
                if (!entry) return;
                controller.entryAction("duplicate", entry);
            } else if (step === 14) {
                const duplicate = controller.files.find(entry => entry.name === "renamed fixture (2).txt");
                if (!duplicate) return;
                controller.entryAction("rename", duplicate);
                const item = main.clipboardControl(window.contentItem, "entryComponent-renamed fixture (2).txt");
                item.nameEditor.text = "cancelled.txt";
                item.cancelRename();
                item.beginRename();
                item.nameEditor.text = "clicked away.txt";
                Qt.callLater(() => window.contentItem.forceActiveFocus());
            } else if (step === 15) {
                if (!controller.files.some(entry => entry.name === "clicked away.txt")) return;
                console.log("CLIPBOARD UI PASSED: standalone behavior, four views, rename, duplicate and cancel");
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
assert (fixtures / 'destination' / 'renamed fixture.txt').read_text() == 'shared clipboard fixture\n'
assert (fixtures / 'destination' / 'clicked away.txt').read_text() == 'shared clipboard fixture\n'
assert not (fixtures / 'destination' / 'cancelled.txt').exists()
print('PASS: standalone behavior, all Files views, rename, duplicate and cancel')
