#!/usr/bin/env python3
"""Read-only integration check against the session's GNOME file index.

Supply names of an indexed existing file and folder. All generated fixtures live
under build/. This never modifies the index or opens/modifies the matched files.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('--file-term', required=True)
parser.add_argument('--folder-term', required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[3]
target = root / 'build/verification/search/ui'
target.mkdir(parents=True, exist_ok=True)
fixture = target / 'location'
fixture.mkdir(exist_ok=True)
(fixture / 'local.txt').write_text('Search origin fixture\n')
for name in ('qml', 'config', 'assets'):
    link = target / name
    if not link.exists():
        link.symlink_to(root / 'gui' / name, target_is_directory=True)
source = (root / 'gui/Main.qml').read_text().replace('import QtQuick', 'import gui\nimport QtQuick', 1)
actions = '''
    Timer {
        interval: 150
        repeat: true
        running: true
        property int step: 0
        property int ticks: 0
        onTriggered: {
            if (++ticks > 200) { console.error("SEARCH FAILED: timeout"); Qt.exit(1); return; }
            if (step === 0) {
                main.controller.openTrashQuickWindow();
                ++step;
                return;
            }
            const controller = main.controller.filesQuickWindow.controller;
            if (!controller) return;
            const directory = controller.directory;
            if (step === 1) {
                directory.open(ORIGIN);
                ++step;
                return;
            }
            if (directory.loading) return;
            if (directory.error.length) { console.error("SEARCH FAILED", directory.error); Qt.exit(1); return; }
            if (step === 2) {
                if (directory.count !== 1) { console.error("SEARCH FAILED: fixture"); Qt.exit(1); return; }
                directory.search = FOLDER_TERM;
                controller.viewMode = "columns";
            } else if (step === 3) {
                if (!controller.folders.length || controller.folders.some(entry => entry.path.startsWith(LOCAL_PATH))) {
                    console.error("SEARCH FAILED: global folders"); Qt.exit(1); return;
                }
                directory.search = FILE_TERM;
                controller.viewMode = "list";
            } else if (step === 4) {
                if (!controller.files.length || controller.files.some(entry => entry.path.startsWith(LOCAL_PATH))) {
                    console.error("SEARCH FAILED: global files"); Qt.exit(1); return;
                }
                // Only the last request may publish results after rapid edits.
                directory.search = "pedro-impossible-match-quote\\\"-[.*]";
                directory.search = FOLDER_TERM;
                controller.viewMode = "grid";
            } else if (step === 5) {
                if (!controller.folders.length || controller.files.length) {
                    console.error("SEARCH FAILED: obsolete request"); Qt.exit(1); return;
                }
                directory.search = "pedro-impossible-match-quote\\\"-[.*]";
            } else if (step === 6) {
                if (directory.count !== 0) { console.error("SEARCH FAILED: literal escaped query"); Qt.exit(1); return; }
                directory.search = "";
                controller.viewMode = "mixed";
            } else if (step === 7) {
                if (directory.count !== 1 || controller.files[0].name !== "local.txt") {
                    console.error("SEARCH FAILED: restore origin"); Qt.exit(1); return;
                }
                console.log("SEARCH PASSED: indexed files/folders outside origin, four views, rapid edits and restore");
                Qt.quit();
            }
            ++step;
        }
    }
'''
for key, value in {'ORIGIN': fixture.as_uri(), 'LOCAL_PATH': str(fixture), 'FILE_TERM': args.file_term, 'FOLDER_TERM': args.folder_term}.items():
    actions = actions.replace(key, json.dumps(value))
position = source.rfind('}')
(target / 'Main.qml').write_text(source[:position] + actions + source[position:])
environment = dict(os.environ, PEDRO_DEVELOPMENT_MODE='1', PEDRO_QML_DIR=str(target),
                   QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software', QT_QPA_PLATFORMTHEME='none')
result = subprocess.run([str(root / 'build/dev/gui/pedro-gui')], env=environment,
                        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=40)
(target / 'check.log').write_text(result.stdout)
if result.returncode or 'SEARCH PASSED' not in result.stdout or any(error in result.stdout for error in ('ReferenceError', 'TypeError', 'SEARCH FAILED')):
    raise SystemExit(result.stdout)
print('PASS: GNOME global file and folder search in Pedro Files')
