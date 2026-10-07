#!/usr/bin/env python3
"""Verify live MIME-based filters against real GIO models and QML buttons."""
import os
from pathlib import Path
import shutil
import subprocess
import wave

root = Path(__file__).resolve().parents[3]
target = root / 'build/verification/files/filters'
target.mkdir(parents=True, exist_ok=True)
fixtures = target / 'fixtures'
shutil.rmtree(fixtures, ignore_errors=True)
fixtures.mkdir()
(fixtures / 'only').mkdir()
(fixtures / 'only/a.txt').write_text('One document\n')
(fixtures / 'a.txt').write_text('Document\n')
(fixtures / 'empty').write_bytes(b'')
(fixtures / 'picture.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" width="8" height="8"><rect width="8" height="8" fill="blue"/></svg>')
(fixtures / 'video.mp4').write_bytes(b'\x00\x00\x00\x18ftypmp42\x00\x00\x00\x00mp42isom')
with wave.open(str(fixtures / 'sound.wav'), 'wb') as sound:
    sound.setnchannels(1)
    sound.setsampwidth(2)
    sound.setframerate(8000)
    sound.writeframes(b'\x00\x00' * 80)
(fixtures / 'script.sh').write_text('#!/bin/sh\necho fixture\n')
shutil.copyfile('/bin/true', fixtures / 'program')
(fixtures / 'unknown.blob').write_bytes(b'\x00\x01\x02\x03' * 20)
for name in ('qml', 'assets'):
    link = target / name
    if not link.exists():
        link.symlink_to(root / 'gui' / name, target_is_directory=True)
shutil.copytree(root / 'gui/config', target / 'config', dirs_exist_ok=True)
source = (root / 'gui/Main.qml').read_text().replace('import QtQuick', 'import QtTest\nimport QtQuick', 1)
probe = r'''
    property var filterWindow: null
    function filterFind(item, name) {
        if (!item) return null;
        if (item.objectName === name) return item;
        for (const child of item.children || []) { const found = filterFind(child, name); if (found) return found; }
        return null;
    }
    function filterRequire(condition, message) { if (!condition) { console.error("FILTER_FAILED", message); Qt.exit(1); } return condition; }
    TestCase { id: filterPointer; when: false }
    Timer {
        interval: 250; running: true; repeat: true
        property int step: 0
        property int ticks: 0
        onTriggered: {
            if (++ticks > 120) { console.error("FILTER_FAILED timeout", step); Qt.exit(1); return; }
            if (step === 0) {
                const loader = main.openFolderWindow("@FIXTURES@");
                if (!loader.item) return;
                filterWindow = loader.item;
            } else if (step === 1) {
                const directory = filterWindow.controller.directory;
                if (directory.loading) return;
                const toolbar = main.filterFind(filterWindow.contentItem, "filesTypeFilters");
                const expected = ["folders", "documents", "images", "videos", "audio", "executables", "shell", "other"];
                if (!main.filterRequire(toolbar.showFilters && expected.every(key => toolbar.categoryKeys.indexOf(key) >= 0), "available types must reflect native MIME data")) return;
                const button = main.filterFind(toolbar, "filesTypeFilter-documents");
                filterPointer.mouseClick(button, 12, 16, Qt.LeftButton);
            } else if (step === 2) {
                const directory = filterWindow.controller.directory;
                const toolbar = main.filterFind(filterWindow.contentItem, "filesTypeFilters");
                if (!main.filterRequire(directory.category === "documents" && directory.files.length === 2 && directory.folders.length === 0 && toolbar.showFilters, "document filtering and empty extensionless document")) return;
                if (!main.filterRequire(directory.entriesModel.rowCount() === 2, "Qt proxy must filter actual rows")) return;
                main.filterFind(toolbar, "filesTypeFilter-all").item.clicked();
            } else if (step === 3) {
                const directory = filterWindow.controller.directory;
                if (!main.filterRequire(directory.files.length === 8 && directory.folders.length === 1, "All must restore every type")) return;
                directory.open("@FIXTURES@/only");
            } else if (step === 4) {
                const directory = filterWindow.controller.directory;
                if (directory.loading) return;
                const toolbar = main.filterFind(filterWindow.contentItem, "filesTypeFilters");
                if (!main.filterRequire(!toolbar.showFilters && toolbar.categoryKeys.length === 1 && directory.category === "all", "single-type folder must hide and reset filters")) return;
                directory.search = "absent";
            } else if (step === 5) {
                const toolbar = main.filterFind(filterWindow.contentItem, "filesTypeFilters");
                if (!main.filterRequire(!toolbar.showFilters && toolbar.categoryKeys.length === 0, "empty search results must hide filters")) return;
                filterWindow.controller.directory.open("@FIXTURES@");
                filterWindow.controller.viewMode = "columns";
            } else if (step === 6) {
                const column = main.filterFind(filterWindow.contentItem, "filesDirectoryColumn-0");
                if (!column || column.directory.loading) return;
                column.openEntry(column.directory.folders[0]);
            } else if (step === 7) {
                const column = main.filterFind(filterWindow.contentItem, "filesDirectoryColumn-1");
                if (!column || column.directory.loading) return;
                const toolbar = main.filterFind(filterWindow.contentItem, "filesTypeFilters");
                if (!main.filterRequire(toolbar.directory === column.directory && !toolbar.showFilters, "column filters must follow the current child directory")) return;
                column.directory.createFolder("new folder");
            } else if (step === 8) {
                const toolbar = main.filterFind(filterWindow.contentItem, "filesTypeFilters");
                if (!toolbar.showFilters) return;
                if (!main.filterRequire(toolbar.categoryKeys.length === 2 && toolbar.categoryKeys.indexOf("folders") >= 0 && toolbar.categoryKeys.indexOf("documents") >= 0, "filesystem changes must update available filters")) return;
                console.log("FILTER_PASSED dynamic types, actual filtering, navigation, search, columns and filesystem changes");
                Qt.quit();
            }
            ++step;
        }
    }
'''.replace('@FIXTURES@', fixtures.as_uri())
position = source.rfind('}')
(target / 'Main.qml').write_text(source[:position] + probe + source[position:])
environment = dict(os.environ, PEDRO_DEVELOPMENT_MODE='1', PEDRO_QML_DIR=str(target),
                   QT_QPA_PLATFORM=os.environ.get('PEDRO_TEST_PLATFORM', 'offscreen'),
                   QT_QUICK_BACKEND=os.environ.get('QT_QUICK_BACKEND', 'software'), QT_QPA_PLATFORMTHEME='none')
result = subprocess.run([str(root / 'build/dev/gui/pedro-gui')], env=environment,
                        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=50)
(target / 'check.log').write_text(result.stdout)
if result.returncode or 'FILTER_PASSED' not in result.stdout or any(value in result.stdout for value in ('FILTER_FAILED', 'TypeError', 'ReferenceError', 'Binding loop')):
    raise SystemExit(result.stdout)
print('PASS: live MIME types, type buttons, single-type hiding, empty files, search and active columns')
