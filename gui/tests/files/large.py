#!/usr/bin/env python3
"""Exercise large directory views and This Computer -> / -> /bin with real GIO.
Fixtures live under build/. System directories are read only. Set
PEDRO_TEST_PLATFORM=wayland and QT_QUICK_BACKEND=rhi for a visible native run.
"""
import os
from pathlib import Path
import shutil
import subprocess

root = Path(__file__).resolve().parents[3]
target = root / 'build/verification/files/large'
target.mkdir(parents=True, exist_ok=True)
fixtures = target / 'fixtures'
shutil.rmtree(fixtures, ignore_errors=True)
fixtures.mkdir()
for index in range(2100):
    (fixtures / f'file-{index:04}.txt').write_text('Large directory fixture\n')
(fixtures / 'empty').mkdir()
for name in ('qml', 'assets'):
    link = target / name
    if not link.exists():
        link.symlink_to(root / 'gui' / name, target_is_directory=True)
shutil.copytree(root / 'gui/config', target / 'config', dirs_exist_ok=True)
source = (root / 'gui/Main.qml').read_text()
probe = r'''
    property var largeWindow: null
    function largeFind(item, name) {
        if (!item) return null;
        if (item.objectName === name) return item;
        for (const child of item.children || []) {
            const result = largeFind(child, name);
            if (result) return result;
        }
        return null;
    }
    function largeDelegates(view) {
        let count = 0;
        for (const child of view.contentItem.children) if (child.entry !== undefined) ++count;
        return count;
    }
    function largeRequire(condition, reason) {
        if (!condition) { console.error("LARGE_FAILED", reason); Qt.exit(1); }
        return condition;
    }
    Timer {
        interval: 250; running: true; repeat: true
        property int step: 0
        property int ticks: 0
        onTriggered: {
            if (++ticks > 240) { console.error("LARGE_FAILED timeout", step); Qt.exit(1); return; }
            if (step === 0) {
                const loader = main.openFolderWindow("@FIXTURES@");
                if (!loader.item) return;
                main.largeWindow = loader.item;
                largeWindow.controller.viewMode = "mixed";
            } else if (step === 1 || step === 2 || step === 3) {
                const list = main.largeFind(largeWindow.contentItem, "filesMixedList");
                const outer = main.largeFind(largeWindow.contentItem, "filesBodyScroll");
                if (!list || largeWindow.controller.directory.loading || list.count !== 2100) return;
                if (!main.largeRequire(main.largeDelegates(list) < 100 && list.height <= outer.availableHeight + 1, "mixed rows must be virtualized")) return;
                console.log("LARGE_MIXED", list.count, main.largeDelegates(list));
                if (step === 1) outer.contentItem.contentY = outer.contentItem.contentHeight / 2;
                if (step === 2) outer.contentItem.contentY = outer.contentItem.contentHeight - outer.contentItem.height;
                if (step === 3) {
                    if (!main.largeRequire(!!list.itemAtIndex(2099), "last mixed row must be accessible")) return;
                    largeWindow.controller.viewMode = "grid";
                    outer.contentItem.contentY = 0;
                }
            } else if (step === 4 || step === 5 || step === 6) {
                const grid = main.largeFind(largeWindow.contentItem, "filesFolderGrid");
                const outer = main.largeFind(largeWindow.contentItem, "filesBodyScroll");
                if (!grid || grid.count !== 2101) return;
                if (!main.largeRequire(main.largeDelegates(grid) < 150 && grid.height <= outer.availableHeight + 1, "grid cards must be virtualized")) return;
                console.log("LARGE_GRID", grid.count, main.largeDelegates(grid));
                if (step === 4) outer.contentItem.contentY = outer.contentItem.contentHeight / 2;
                if (step === 5) outer.contentItem.contentY = outer.contentItem.contentHeight - outer.contentItem.height;
                if (step === 6) {
                    if (!main.largeRequire(!!grid.itemAtIndex(2100), "last grid card must be accessible")) return;
                    largeWindow.controller.viewMode = "list";
                }
            } else if (step === 7) {
                const list = main.largeFind(largeWindow.contentItem, "filesFileList");
                if (!list || list.count !== 2101) return;
                if (!main.largeRequire(main.largeDelegates(list) < 100, "standalone list must be virtualized")) return;
                largeWindow.controller.viewMode = "columns";
                largeWindow.controller.openPlace("computer");
            } else if (step === 8) {
                const column = main.largeFind(largeWindow.contentItem, "filesDirectoryColumn-0");
                if (!column || column.directory.loading) return;
                if (!main.largeRequire(column.directory.location === "pedro:computer", "Computer column must accept its virtual URI")) return;
                const entry = column.directory.folders.find(entry => entry.url === "file:///");
                if (!main.largeRequire(!!entry, "Computer must contain filesystem root")) return;
                column.openEntry(entry);
            } else if (step === 9) {
                const column = main.largeFind(largeWindow.contentItem, "filesDirectoryColumn-1");
                if (!column || column.directory.loading) return;
                const entry = column.directory.folders.find(entry => entry.name === "bin");
                if (!main.largeRequire(!!entry && entry.isDirectory, "bin symlink must navigate as a folder")) return;
                column.openEntry(entry);
            } else if (step === 10) {
                const column = main.largeFind(largeWindow.contentItem, "filesDirectoryColumn-2");
                if (!column || column.directory.loading) return;
                if (!main.largeRequire(column.directory.count > 0 && !column.directory.error.length, "/bin must load its actual contents")) return;
                console.log("LARGE_BIN", column.directory.count);
                largeWindow.controller.directory.open("file:///usr/bin");
            } else if (step === 11) {
                const column = main.largeFind(largeWindow.contentItem, "filesDirectoryColumn-0");
                if (!column || column.directory.loading) return;
                if (!main.largeRequire(column.directory.location === "file:///usr/bin" && column.directory.count > 0 && !column.directory.error.length, "/usr/bin must load")) return;
                largeWindow.controller.viewMode = "mixed";
            } else if (step === 12) {
                const list = main.largeFind(largeWindow.contentItem, "filesMixedList");
                if (!list || list.count < 1) return;
                if (!main.largeRequire(main.largeDelegates(list) < 100, "binary directory must keep a bounded visual population")) return;
                largeWindow.controller.viewMode = "columns";
                largeWindow.controller.directory.open("@FIXTURES@/missing");
            } else if (step === 13) {
                const column = main.largeFind(largeWindow.contentItem, "filesDirectoryColumn-0");
                if (!column || column.directory.loading) return;
                const message = main.largeFind(column, "filesColumnError");
                if (!main.largeRequire(column.directory.count === 0 && column.directory.error.length > 0 && message && message.visible, "directory query failure must show an error without closing")) return;
                console.log("LARGE_PASSED system navigation, bounded views and native directory errors");
                Qt.quit();
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
                   QT_QUICK_BACKEND=os.environ.get('QT_QUICK_BACKEND', 'software'),
                   QT_QPA_PLATFORMTHEME='none')
result = subprocess.run([str(root / 'build/dev/gui/pedro-gui')], env=environment,
                        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=90)
(target / 'check.log').write_text(result.stdout)
if result.returncode or 'LARGE_PASSED' not in result.stdout or any(value in result.stdout for value in ('LARGE_FAILED', 'TypeError', 'ReferenceError', 'Binding loop')):
    raise SystemExit(result.stdout)
print('PASS: 2100 files, mixed/grid virtualization, end scrolling, Computer -> / -> /bin, /usr/bin')
