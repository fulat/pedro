#!/usr/bin/env python3
"""Exercise inline global tags, GIO metadata, GNOME persistence and global results."""
import os
from pathlib import Path
import shutil
import subprocess

root = Path(__file__).resolve().parents[3]
target = root / 'build/verification/files/tags'
target.mkdir(parents=True, exist_ok=True)
if not os.environ.get('PEDRO_TAG_TEST_REUSE'):
    shutil.rmtree(target / 'data', ignore_errors=True)
    shutil.rmtree(target / 'fixtures', ignore_errors=True)
for name in ('a', 'b'):
    (target / 'fixtures' / name).mkdir(parents=True, exist_ok=True)
(target / 'fixtures/a/file a.txt').write_text('First file\n')
(target / 'fixtures/b/file b.txt').write_text('Other directory\n')
for name in ('qml', 'assets'):
    link = target / name
    if not link.exists():
        link.symlink_to(root / 'gui' / name, target_is_directory=True)
shutil.copytree(root / 'gui/config', target / 'config', dirs_exist_ok=True)
source = (root / 'gui/Main.qml').read_text().replace('import QtQuick', 'import Pedro.Files 1.0\nimport QtTest\nimport QtQuick', 1)
probe = r'''
    property var tagWindow: null
    property string probeTag: ""
    function tagFind(item, name) {
        if (!item) return null;
        if (item.objectName === name) return item;
        for (const child of item.children || []) { const found = tagFind(child, name); if (found) return found; }
        return null;
    }
    function tagRequire(value, text) { if (!value) { console.error("TAG_FAILED", text, Tags.error); Qt.exit(1); } return value; }
    TestCase { id: tagPointer; when: false }
    Timer {
        interval: 300; repeat: true; running: true
        property int step: 0
        property int ticks: 0
        property bool executing: false
        onTriggered: {
            if (executing) return;
            executing = true;
            try {
            if (++ticks > 180) { console.error("TAG_FAILED timeout", step, Tags.error); Qt.exit(1); return; }
            if (step === 0) {
                const loader = main.openFolderWindow("@A@");
                if (!loader.item) return;
                tagWindow = loader.item;
            } else if (step === 1) {
                if (tagWindow.controller.directory.loading) return;
                if (!main.tagRequire(Tags.rowCount() >= 4 && !Tags.error.length, "GNOME tag registry must load")) return;
                const add = main.tagFind(tagWindow.contentItem, "tagsAdd");
                if (!add) return;
                tagPointer.mouseClick(add, 14, 14, Qt.LeftButton);
            } else if (step === 2) {
                const newest = Tags.tags[Tags.tags.length - 1];
                if (!main.tagRequire(Tags.tags.length === 5, "inline plus must create one tag")) return;
                probeTag = newest.id;
                const editor = main.tagFind(tagWindow.contentItem, "tagEditor-" + probeTag);
                if (!main.tagRequire(editor && editor.visible && editor.activeFocus, "new tag name must edit inline")) return;
                const color = main.tagFind(tagWindow.contentItem, "tagColor-" + probeTag + "-#13b5b1");
                tagPointer.mouseClick(color, 10, 10, Qt.LeftButton);
                if (!main.tagRequire(editor.visible && Tags.definition(probeTag).color === "#13b5b1", "inline color palette must preserve rename editing")) return;
                editor.text = "Project fixture";
                tagPointer.keyClick(Qt.Key_Return);
            } else if (step === 3) {
                if (!main.tagRequire(Tags.definition(probeTag).name === "Project fixture", "inline rename must persist")) return;
                Tags.assign("@FILE_A@", probeTag, true);
            } else if (step === 4) {
                if (Tags.busy) return;
                if (!main.tagRequire(Tags.fileTags("@FILE_A@").indexOf(probeTag) >= 0 && !Tags.error.length, "GIO metadata assignment and catalogue")) return;
                Tags.assign("@FILE_B@", probeTag, true);
            } else if (step === 5) {
                if (Tags.busy) return;
                if (!main.tagRequire(Tags.fileTags("@FILE_B@").indexOf(probeTag) >= 0, "second directory assignment")) return;
                const row = main.tagFind(tagWindow.contentItem, "tag-" + probeTag);
                tagPointer.mouseClick(row, 40, 16, Qt.LeftButton);
            } else if (step === 6) {
                const directory = tagWindow.controller.directory;
                if (directory.loading) return;
                if (!main.tagRequire(String(directory.location) === "pedro:tag:" + probeTag && directory.count === 2, "tag click must search beyond current directory")) return;
                if (!main.tagRequire(tagWindow.controller.title === "Project fixture", "tag results title")) return;
                Tags.rename(probeTag, "Renamed fixture");
                tagWindow.controller.informationRequested(directory.files[0]);
            } else if (step === 7) {
                const panel = main.tagFind(tagWindow.contentItem, "filesColumnDetails");
                if (!panel || panel.metadata.size === undefined) return;
                if (!main.tagRequire(panel.assignedTags.indexOf(probeTag) >= 0 && tagWindow.controller.title === "Renamed fixture" && Tags.definition(probeTag).color === "#13b5b1", "renaming/color must preserve assignment and update all views")) return;
                panel.editingTags = true;
                Backend.fileTransfer.rename("@FILE_A@", "renamed a.txt");
            } else if (step === 8) {
                if (Backend.fileTransfer.busy || tagWindow.controller.directory.loading) return;
                if (!main.tagRequire(Tags.fileTags("@RENAMED_A@").indexOf(probeTag) >= 0 && Tags.fileTags("@FILE_A@").length === 0, "tag catalogue follows native rename")) return;
                Tags.assign("@FILE_B@", probeTag, false);
            } else if (step === 9) {
                if (Tags.busy || tagWindow.controller.directory.loading) return;
                if (!main.tagRequire(tagWindow.controller.directory.count === 1 && Tags.fileTags("@FILE_B@").length === 0, "removing a file tag updates global results")) return;
                console.log("TAG_PERSIST", probeTag);
                console.log("TAG_PASSED inline creation, rename, color, metadata, global query and file rename");
                Qt.quit();
            }
            ++step;
            } finally { executing = false; }
        }
    }
'''
replacements = {'@A@': (target / 'fixtures/a').as_uri(), '@FILE_A@': (target / 'fixtures/a/file a.txt').as_uri(), '@FILE_B@': (target / 'fixtures/b/file b.txt').as_uri(), '@RENAMED_A@': (target / 'fixtures/a/renamed a.txt').as_uri()}
for key, value in replacements.items():
    probe = probe.replace(key, value)
position = source.rfind('}')
(target / 'Main.qml').write_text(source[:position] + probe + source[position:])
environment = dict(os.environ, PEDRO_DEVELOPMENT_MODE='1', PEDRO_QML_DIR=str(target),
                   XDG_DATA_HOME=str(target / 'data'),
                   QT_QPA_PLATFORM=os.environ.get('PEDRO_TEST_PLATFORM', 'offscreen'),
                   QT_QUICK_BACKEND=os.environ.get('QT_QUICK_BACKEND', 'software'), QT_QPA_PLATFORMTHEME='none')
result = subprocess.run([str(root / 'build/dev/gui/pedro-gui')], env=environment,
                        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=90)
(target / 'check.log').write_text(result.stdout)
if result.returncode or 'TAG_PASSED' not in result.stdout or any(value in result.stdout for value in ('TAG_FAILED', 'TypeError', 'ReferenceError', 'Binding loop')):
    raise SystemExit(result.stdout)
id = result.stdout.split('TAG_PERSIST ')[1].splitlines()[0]
# Re-open the same native database in a fresh process; delete a tag afterwards.
second = r'''
    Timer { interval: 1000; running: true; onTriggered: {
        const id = "@ID@";
        if (Tags.definition(id).name !== "Renamed fixture" || Tags.definition(id).color !== "#13b5b1" || Tags.fileTags("@SOURCE@").indexOf(id) < 0) { console.error("TAG_FAILED restart persistence"); Qt.exit(1); return; }
        if (!Tags.remove(id)) { console.error("TAG_FAILED deletion", Tags.error); Qt.exit(1); return; }
        complete.start();
    } }
    Timer { id: complete; interval: 200; repeat: true; onTriggered: {
        if (Tags.busy) return;
        if (Tags.definition("@ID@").id || Tags.fileTags("@SOURCE@").length || Tags.error.length) { console.error("TAG_FAILED deletion cleanup", Tags.error); Qt.exit(1); return; }
        console.log("TAG_PASSED restart and deletion"); Qt.quit();
    } }
'''.replace('@ID@', id).replace('@SOURCE@', replacements['@RENAMED_A@'])
(target / 'Main.qml').write_text(source[:position] + second + source[position:])
result = subprocess.run([str(root / 'build/dev/gui/pedro-gui')], env=environment, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=30)
(target / 'restart.log').write_text(result.stdout)
if result.returncode or 'TAG_PASSED' not in result.stdout or any(value in result.stdout for value in ('TAG_FAILED', 'TypeError', 'ReferenceError', 'Binding loop')):
    raise SystemExit(result.stdout)
print('PASS: inline global tags, native metadata, rename/move tracking, restart persistence and deletion')
