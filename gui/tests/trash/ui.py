#!/usr/bin/env python3
"""Load the real Files/Trash UI offscreen; never accept a deletion dialog."""
import os
import json
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[3]
target = root / 'build/verification/trash/ui'
target.mkdir(parents=True, exist_ok=True)
for name in ('qml', 'config', 'assets'):
    link = target / name
    if not link.exists():
        link.symlink_to(root / 'gui' / name, target_is_directory=True)
source = (root / 'gui/Main.qml').read_text().replace('import QtQuick', 'import gui\nimport QtQuick', 1)
actions = '''
    function findTrashControl(item, name) {
        if (item.objectName === name) return item;
        for (const child of item.children || []) {
            const result = findTrashControl(child, name);
            if (result) return result;
        }
        return null;
    }
    Timer {
        interval: 800
        running: true
        repeat: true
        property int step: 0
        property var probe: null
        property int acceptedCount: 0
        property int rejectedCount: 0
        onTriggered: {
            if (step === 0) {
                main.controller.openTrashQuickWindow();
            } else if (step === 1) {
                const controller = main.controller.filesQuickWindow.controller;
                if (!controller || controller.directory.place !== "trash" || controller.directory.error.length) {
                    console.error("TRASH UI FAILED");
                    Qt.exit(1);
                    return;
                }
                const surface = main.controller.filesQuickWindow.contentItem.parent.parent;
                const empty = main.findTrashControl(surface, "trashEmpty");
                const restore = main.findTrashControl(surface, "trashRestore");
                if (!empty || restore || empty.visible !== (controller.files.length + controller.folders.length > 0)
                    || empty.mapToItem(surface, 0, 0).y >= 58) {
                    console.error("TRASH UI FAILED: header placement/visibility");
                    Qt.exit(1);
                    return;
                }
                const entry = controller.files.concat(controller.folders)[0];
                if (entry) controller.select(entry);
                const component = Qt.createComponent("qml/components/entry/trash.qml");
                if (component.status !== Component.Ready) {
                    console.error("TRASH UI FAILED", component.errorString());
                    Qt.exit(1);
                    return;
                }
                const menu = component.createObject(main.contentItem, {canRestore: true, backdrop: main.entryBackdrop});
                if (!menu || menu.count !== 8) {
                    console.error("TRASH UI FAILED: restore/delete menu");
                    Qt.exit(1);
                    return;
                }
                menu.popup(20, 20);
                menu.close();
                menu.destroy();
                // Exercise the permanent-delete dialog, without accepting it.
                controller.removalRequested(["trash:///pedro-test-not-a-real-item"]);
            } else if (step === 2) {
                const owner = main.controller.filesQuickWindow;
                const confirmation = owner.contentItem.confirmationWindow;
                if (!confirmation.visible || confirmation.ownerWindow !== owner || confirmation.transientParent !== null || confirmation.modality !== Qt.ApplicationModal || (confirmation.flags & Qt.WindowStaysOnTopHint) === 0 || (confirmation.flags & Qt.Dialog) === Qt.Dialog) {
                    console.error("TRASH UI FAILED: independent confirmation window");
                    Qt.exit(1);
                    return;
                }
                confirmation.contentItem.grabToImage(result => result.saveToFile(ALERT_IMAGE));
            } else if (step === 3) {
                const owner = main.controller.filesQuickWindow;
                owner.contentItem.confirmationWindow.reject();
                const component = Qt.createComponent("qml/components/confirmation/window.qml");
                probe = component.createObject(main, {ownerWindow: owner, title: "Pedro test", message: "Reusable confirmation", confirmText: "Confirm"});
                if (!probe) {
                    console.error("TRASH UI FAILED", component.errorString());
                    Qt.exit(1);
                    return;
                }
                probe.accepted.connect(() => ++acceptedCount);
                probe.rejected.connect(() => ++rejectedCount);
                probe.open();
                owner.requestActivate();
            } else if (step === 4) {
                const cancel = main.findTrashControl(probe.contentItem, "confirmationCancel");
                if (!cancel || !cancel.activeFocus) {
                    console.error("TRASH UI FAILED: safe default focus");
                    Qt.exit(1);
                    return;
                }
                const ownerX = probe.ownerWindow.x;
                const ownerY = probe.ownerWindow.y;
                const oldX = probe.x;
                probe.x = oldX + 20;
                if (probe.x !== oldX + 20 || probe.ownerWindow.x !== ownerX || probe.ownerWindow.y !== ownerY) {
                    console.error("TRASH UI FAILED: movable window");
                    Qt.exit(1);
                    return;
                }
                probe.close();
                if (rejectedCount !== 1 || acceptedCount !== 0) {
                    console.error("TRASH UI FAILED: close must cancel");
                    Qt.exit(1);
                    return;
                }
                probe.open();
                probe.actionEnabled = false;
                probe.accept();
                if (acceptedCount !== 0 || !probe.visible) {
                    console.error("TRASH UI FAILED: disabled confirmation");
                    Qt.exit(1);
                    return;
                }
                probe.actionEnabled = true;
                probe.accept();
                probe.accept();
                if (acceptedCount !== 1 || rejectedCount !== 1 || probe.visible) {
                    console.error("TRASH UI FAILED: exactly one result");
                    Qt.exit(1);
                    return;
                }
                probe.showCancel = false;
                probe.confirmText = "OK";
                probe.open();
            } else if (step === 5) {
                const accept = main.findTrashControl(probe.contentItem, "confirmationAccept");
                const cancel = main.findTrashControl(probe.contentItem, "confirmationCancel");
                if (!accept.activeFocus || cancel.visible) {
                    console.error("TRASH UI FAILED: acknowledgement alert");
                    Qt.exit(1);
                    return;
                }
                probe.accept();
                if (acceptedCount !== 2 || rejectedCount !== 1) {
                    console.error("TRASH UI FAILED: acknowledgement result");
                    Qt.exit(1);
                    return;
                }
                probe.destroy();
            } else {
                console.log("TRASH UI PASSED: listing, toolbar and deletion confirmation loaded");
                Qt.quit();
            }
            ++step;
        }
    }
'''
actions = actions.replace('ALERT_IMAGE', json.dumps(str(target / 'alert.png')))
position = source.rfind('}')
(target / 'Main.qml').write_text(source[:position] + actions + source[position:])
environment = dict(os.environ, PEDRO_DEVELOPMENT_MODE='1', PEDRO_QML_DIR=str(target),
                   QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software', QT_QPA_PLATFORMTHEME='none')
try:
    result = subprocess.run([str(root / 'build/dev/gui/pedro-gui')], env=environment,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=40)
except subprocess.TimeoutExpired as error:
    output = error.stdout.decode(errors='replace') if isinstance(error.stdout, bytes) else error.stdout or ''
    (target / 'check.log').write_text(output)
    raise SystemExit('Trash UI timed out:\n' + output)
(target / 'check.log').write_text(result.stdout)
if result.returncode or 'TRASH UI PASSED' not in result.stdout or any(error in result.stdout for error in ('ReferenceError', 'TypeError', 'Error:', 'TRASH UI FAILED', 'Binding loop detected for property "minimumHeight"')):
    raise SystemExit(result.stdout)
print('PASS: real Pedro Trash listing, toolbar and confirmation UI')
