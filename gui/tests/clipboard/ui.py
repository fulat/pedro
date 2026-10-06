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
for directory in ('source', 'destination', 'desktop'):
    (fixtures / directory).mkdir(parents=True)
(fixtures / 'source' / 'shared.txt').write_text('shared clipboard fixture\n')
(fixtures / 'source' / 'drop.txt').write_text('Shared drop fixture\n')
(fixtures / 'destination' / 'nested').mkdir()
chain = fixtures / 'destination' / 'Deep'
for level in range(8):
    chain.mkdir()
    chain = chain / ('level' + str(level + 1))
(fixtures / 'destination' / 'viewer.txt').write_text('Viewer tracking fixture\n')
for name in ('qml', 'config', 'assets'):
    link = target / name
    if not link.exists():
        link.symlink_to(root / 'gui' / name, target_is_directory=True)
source = (root / 'gui/Main.qml').read_text().replace('import QtQuick', 'import gui\nimport QtTest\nimport QtQuick', 1)
actions = '''
    TestCase { id: pointerProbe; when: false }
    property var dragPointer: null
    Timer {
        id: dragRelease
        interval: 60
        onTriggered: {
            if (main.dragPointer) pointerProbe.mouseRelease(main.dragPointer, 48, 16, Qt.LeftButton, Qt.NoModifier, 0);
        }
    }
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
        property bool executing: false
        property int emptyCycles: 0
        property real originalHeight: 0
        property int depth: 0
        property var panel: null
        property var standaloneFile: null
        property var standaloneFolder: null
        property bool applicationsChecked: false
        property var previewSession: null
        property int previewCount: 0
        onTriggered: {
            if (executing) return;
            executing = true;
            try {
            if (++ticks > 250) { console.error("CLIPBOARD UI FAILED: timeout", step); Qt.exit(1); return; }
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
                if (controller.viewMode === "columns") {
                    main.clipboardControl(window.contentItem, "filesColumns").detailEntry = null;
                    pointerProbe.wait(20);
                }
                pointerProbe.mouseClick(window.contentItem, window.contentItem.width - 40,
                    window.contentItem.height - 45, Qt.RightButton);
                if (!menu.visible) { console.error("CLIPBOARD UI FAILED: background right click did not open menu"); Qt.exit(1); return; }
                const createFolder = main.clipboardControl(menu.contentItem, "filesCreateFolder");
                const createFile = main.clipboardControl(menu.contentItem, "filesCreateFile");
                createFolder.text = "context folder";
                createFolder.triggered();
                createFile.text = "context.txt";
                createFile.triggered();
                function submenu(root, name) {
                    for (let index = 0; index < root.count; ++index) {
                        const child = root.itemAt(index).subMenu;
                        if (child && child.objectName === name) return child;
                    }
                    return null;
                }
                const organization = submenu(menu, "filesBackgroundOrganizationMenu");
                if (!organization || organization.title === "desktop.menu.organization") { console.error("CLIPBOARD UI FAILED: organization menu"); Qt.exit(1); return; }
                const select = main.clipboardControl(menu.contentItem, "filesSelectAll");
                select.triggered();
                if (controller.selectedEntries.length !== controller.directory.count) { console.error("CLIPBOARD UI FAILED: select all"); Qt.exit(1); return; }
                controller.clearSelection();
                function action(root, name) {
                    for (let index = 0; index < root.count; ++index) {
                        if (root.itemAt(index).objectName === name) return root.itemAt(index);
                    }
                    return null;
                }
                const view = action(organization, "filesBackgroundView-list");
                const sort = action(organization, "filesBackgroundSort-type");
                const options = main.clipboardControl(menu.contentItem, "filesBackgroundOptions");
                if (!view || !sort || !options || options.text === "files.menu.options") { console.error("CLIPBOARD UI FAILED: menu options or runtime translations"); Qt.exit(1); return; }
                view.triggered();
                sort.triggered();
                if (controller.viewMode !== "list" || controller.sortKey !== "type") {
                    console.error("CLIPBOARD UI FAILED: context choices do not update header state"); Qt.exit(1); return;
                }
                controller.viewMode = "mixed";
                controller.sortKey = "name";
                menu.close();
                const paste = main.clipboardControl(menu.contentItem, "filesPaste");
                if (!paste || !paste.enabled || !Backend.clipboard.canPaste) {
                    console.error("CLIPBOARD UI FAILED: folder paste unavailable"); Qt.exit(1); return;
                }
                paste.triggered();
            } else if (step === 3) {
                const entry = controller.files.find(entry => entry.name === "shared.txt");
                if (!entry) return;
                const component = main.clipboardControl(window.contentItem, "entryComponent-shared.txt");
                if (!component) return;
                main.dragPointer = component.inputSurface.children.find(child => child.objectName === "entryPointer");
                if (!main.dragPointer || !main.dragPointer.preventStealing) { console.error("CLIPBOARD UI FAILED: shared drag input"); Qt.exit(1); return; }
                pointerProbe.mousePress(main.dragPointer, 16, 16, Qt.LeftButton, Qt.NoModifier, 0);
                dragRelease.start();
                pointerProbe.mouseMove(main.dragPointer, 48, 16, 0, Qt.LeftButton);
                if (!main.dragPointer.dragged) { console.error("CLIPBOARD UI FAILED: source component did not initiate drag"); Qt.exit(1); return; }
                if (dragRelease.running) {
                    dragRelease.stop();
                    pointerProbe.mouseRelease(main.dragPointer, 48, 16, Qt.LeftButton, Qt.NoModifier, 0);
                }
                main.dragPointer = null;
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
                Backend.clipboard.copy([item.entry.url]);
                if (item.cutPending || icon.opacity !== 1) {
                    console.error("CLIPBOARD UI FAILED: copy must restore opacity"); Qt.exit(1); return;
                }
                controller.entryAction("cut", item.entry);
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
                standaloneFile.label = "Vacation photographs from Santo Domingo and the Caribbean coastline, final edited version.png";
                const renderer = standaloneFile.nameEditor.parent;
                const label = main.clipboardControl(renderer, "entryNameLabel");
                label.forceLayout();
                if (label.lineCount > 2 || !label.text.endsWith(".png") || !label.text.includes("…")) { console.error("CLIPBOARD UI FAILED: multiline name elision"); Qt.exit(1); return; }
                for (const mode of ["light", "dark"]) {
                    renderer.appearanceMode = mode;
                    if (standaloneFile.nameEditor.selectionColor.a >= 0.6 || String(standaloneFile.nameEditor.color) !== String(standaloneFile.nameEditor.selectedTextColor)) {
                        console.error("CLIPBOARD UI FAILED: unreadable rename selection", mode); Qt.exit(1); return;
                    }
                }
                standaloneFile.label = "shared.txt";
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
            } else if (step === 7) {
                if (!applicationsChecked) {
                    const menu = standaloneFile.item.menu;
                    let openWith = null;
                    for (let i = 0; i < menu.count; ++i) {
                        const candidate = menu.itemAt(i).subMenu;
                        if (candidate && candidate.applications !== undefined) openWith = candidate;
                    }
                    if (!openWith) { console.error("CLIPBOARD UI FAILED: shared Open with submenu missing"); Qt.exit(1); return; }
                    if (openWith.discovering) return;
                    if (!openWith.applications.length) { console.error("CLIPBOARD UI FAILED: no MIME application choices"); Qt.exit(1); return; }
                    const first = openWith.itemAt(0);
                    if (first.objectName !== "openWith-" + openWith.applications[0].id) { console.error("CLIPBOARD UI FAILED: application menu not populated"); Qt.exit(1); return; }
                    applicationsChecked = true;
                    if (!standaloneFolder.dropFiles([SOURCE_FILE])) { console.error("CLIPBOARD UI FAILED: standalone folder drop"); Qt.exit(1); return; }
                    return;
                }
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
                if (step === 9) {
                    const count = main.previewWindows.length;
                    pointerProbe.mouseClick(item.inputSurface, 20, 16, Qt.LeftButton);
                    const details = main.clipboardControl(window.contentItem, "filesColumnDetails");
                    if (main.previewWindows.length !== count || !details || details.entry.name !== "shared.txt" || item.activateOnClick) {
                        console.error("CLIPBOARD UI FAILED: single column click must show details, not open"); Qt.exit(1); return;
                    }
                    pointerProbe.mouseDoubleClickSequence(item.inputSurface, 20, 16, Qt.LeftButton);
                    if (main.previewWindows.length !== count + 1) { console.error("CLIPBOARD UI FAILED: double column click must open"); Qt.exit(1); return; }
                    main.previewWindows[main.previewWindows.length - 1].session.close();
                }
                item.dispatch("cut");
                pointerProbe.mouseClick(item.inputSurface, 20, 16, Qt.RightButton);
                if (!item.menu.visible || item.menu.canCut || !item.cutPending) { console.error("CLIPBOARD UI FAILED: view behavior differs"); Qt.exit(1); return; }
                item.menu.close();
                if (controller.viewMode === "columns") {
                    main.clipboardControl(window.contentItem, "filesColumns").detailEntry = null;
                    pointerProbe.wait(20);
                }
                pointerProbe.mouseClick(window.contentItem, window.contentItem.width - 40,
                    window.contentItem.height - 45, Qt.RightButton);
                if (!window.contentItem.backgroundContextMenu.visible) { console.error("CLIPBOARD UI FAILED: background menu in view", controller.viewMode); Qt.exit(1); return; }
                window.contentItem.backgroundContextMenu.close();
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
                Qt.callLater(() => {
                    pointerProbe.mouseClick(item.nameEditor, item.nameEditor.width / 2, item.nameEditor.height / 2);
                    if (!item.renaming) { console.error("CLIPBOARD UI FAILED: click inside editor committed"); Qt.exit(1); return; }
                    pointerProbe.mouseClick(item, item.width / 2, 16);
                    if (item.renaming) { console.error("CLIPBOARD UI FAILED: icon click did not commit"); Qt.exit(1); }
                });
            } else if (step === 15) {
                if (!controller.files.some(entry => entry.name === "clicked away.txt")) return;
                Backend.openPreview(DESTINATION + "/viewer.txt");
            } else if (step === 16) {
                const loader = main.previewWindows.find(candidate => candidate.session.source.toString().endsWith("/viewer.txt"));
                if (!loader || !loader.item || loader.session.busy) return;
                previewSession = loader.session;
                previewCount = main.previewWindows.length;
                Backend.fileTransfer.rename(previewSession.source, "viewer renamed.txt");
            } else if (step === 17) {
                if (Backend.fileTransfer.busy || !previewSession.source.toString().endsWith("/viewer renamed.txt")) return;
                Backend.openPreview(previewSession.source);
                if (main.previewWindows.length !== previewCount) { console.error("CLIPBOARD UI FAILED: renamed preview duplicated"); Qt.exit(1); return; }
                Backend.fileTransfer.move([previewSession.source], SOURCE_FOLDER);
            } else if (step === 18) {
                if (Backend.fileTransfer.busy || previewSession.source.toString() !== SOURCE_FOLDER + "/viewer renamed.txt") return;
                if (!previewSession.saveText("Saved after move\\n")) { console.error("CLIPBOARD UI FAILED: moved preview save"); Qt.exit(1); return; }
                Backend.openPreview(previewSession.source);
                if (main.previewWindows.length !== previewCount) { console.error("CLIPBOARD UI FAILED: moved preview duplicated"); Qt.exit(1); return; }
            } else if (step === 19) {
                const target = main.clipboardControl(main.contentItem, "desktopDropDestination");
                if (!target) { console.error("CLIPBOARD UI FAILED: desktop has no shared drop destination"); Qt.exit(1); return; }
                target.location = DESKTOP;
                if (!target.dropFiles([SOURCE_FOLDER + "/drop.txt"])) { console.error("CLIPBOARD UI FAILED: file drop on desktop"); Qt.exit(1); return; }
            } else if (step === 20) {
                const target = main.clipboardControl(window.contentItem, "filesDropDestination");
                if (!target || !target.dropFiles([DESKTOP + "/drop.txt"])) { console.error("CLIPBOARD UI FAILED: desktop file drop into Finder"); Qt.exit(1); return; }
            } else if (step === 21) {
                if (!controller.files.some(entry => entry.name === "drop.txt")) return;
                const entry = controller.files.find(entry => entry.name === "drop.txt");
                controller.informationRequested(entry);
            } else if (step === 22) {
                const panel = main.clipboardControl(window.contentItem, "filesColumnDetails");
                if (!panel || panel.metadata.size === undefined) return;
                if (panel.metadata.size !== 20 || !panel.metadata.owner || !panel.metadata.location) {
                    console.error("CLIPBOARD UI FAILED: real file information panel"); Qt.exit(1); return;
                }
                const handle = main.clipboardControl(window.contentItem, "filesColumnResizeHandle");
                const before = panel.width;
                if (!handle || !panel.columnMode) { console.error("CLIPBOARD UI FAILED: information column divider"); Qt.exit(1); return; }
                pointerProbe.mousePress(handle, 4, 40, Qt.LeftButton, Qt.NoModifier, 0);
                pointerProbe.mouseMove(handle, 54, 40, 0, Qt.LeftButton);
                pointerProbe.mouseRelease(handle, 4, 40, Qt.LeftButton, Qt.NoModifier, 0);
                pointerProbe.wait(20);
                if (panel.width >= before) { console.error("CLIPBOARD UI FAILED: information column resize"); Qt.exit(1); return; }
                const entry = controller.files.find(entry => entry.name === "drop.txt");
                main.controller.entryAction("properties", entry);
            } else if (step === 23) {
                const loader = main.informationWindows[0];
                if (!loader || !loader.item || !loader.item.contentItem || loader.item.contentItem.metadata.size === undefined) return;
                if (loader.item.contentItem.metadata.size !== 20) { console.error("CLIPBOARD UI FAILED: shared desktop information window"); Qt.exit(1); return; }
                main.openInformationWindow(loader.entry);
                if (main.informationWindows.length !== 1) { console.error("CLIPBOARD UI FAILED: duplicate information window"); Qt.exit(1); return; }
                loader.item.close();
                controller.viewMode = "columns";
            } else if (step === 24) {
                const column = main.clipboardControl(window.contentItem, "filesDirectoryColumn-0");
                if (!column || column.directory.loading) return;
                column.openEntry(column.directory.folders.find(entry => entry.name === "nested"));
            } else if (step === 25) {
                const columns = main.clipboardControl(window.contentItem, "filesColumns");
                const column = main.clipboardControl(window.contentItem, "filesDirectoryColumn-0");
                if (columns.locations.length !== 2 || columns.detailEntry || !main.clipboardControl(window.contentItem, "filesDirectoryColumn-1")) {
                    console.error("CLIPBOARD UI FAILED: folder contents hierarchy"); Qt.exit(1); return;
                }
                const list = main.clipboardControl(column, "filesColumnList");
                const bar = main.clipboardControl(column, "filesColumnScrollBar");
                if (!bar || bar.parent !== column || bar.x < list.x + list.width) { console.error("CLIPBOARD UI FAILED: folder scrollbar overlaps column content"); Qt.exit(1); return; }
                column.select(column.directory.files.find(entry => entry.name === "drop.txt"));
            } else if (step === 26) {
                const columns = main.clipboardControl(window.contentItem, "filesColumns");
                const details = main.clipboardControl(window.contentItem, "filesColumnDetails");
                if (columns.locations.length !== 1 || !details || Math.abs(details.width - Math.max(260, columns.availableWidth - main.clipboardControl(window.contentItem, "filesDirectoryColumn-0").width)) > 1 || !details.columnMode || main.clipboardControl(window.contentItem, "filesDirectoryColumn-1")) {
                    console.error("CLIPBOARD UI FAILED: compact file information hierarchy"); Qt.exit(1); return;
                }
                if (main.clipboardControl(details, "filesColumnResizeHandle")) { console.error("CLIPBOARD UI FAILED: trailing information divider"); Qt.exit(1); return; }
                const column = main.clipboardControl(window.contentItem, "filesDirectoryColumn-0");
                const handle = main.clipboardControl(column, "filesColumnResizeHandle");
                const before = column.width;
                pointerProbe.mousePress(handle, 4, 40, Qt.LeftButton, Qt.NoModifier, 0);
                pointerProbe.mouseMove(handle, 24, 40, 0, Qt.LeftButton);
                pointerProbe.mouseRelease(handle, 4, 40, Qt.LeftButton, Qt.NoModifier, 0);
                pointerProbe.wait(20);
                if (column.width <= before || Math.abs(details.width - (columns.informationSpan >= 0 ? Math.max(0, columns.informationSpan - column.width) : Math.max(260, columns.availableWidth - column.width))) > 1) { console.error("CLIPBOARD UI FAILED: information must fill space after folder resize"); Qt.exit(1); return; }
                if (main.Screen.width > 1000 && Qt.platform.os === "linux") {
                    window.contentItem.grabToImage(result => result.saveToFile(CAPTURE_PATH));
                }
                controller.informationRequested(details.entry);
                if (!columns.detailEntry) { console.error("CLIPBOARD UI FAILED: information hierarchy command"); Qt.exit(1); return; }
                const content = main.clipboardControl(details, "filesInformationContent");
                if (!content || !content.clip || !content.contentItem || content.contentItem.contentY === undefined) { console.error("CLIPBOARD UI FAILED: information must scroll vertically"); Qt.exit(1); return; }
                originalHeight = window.height;
                window.height = 1200;
                pointerProbe.wait(40);
                const fittedBar = main.clipboardControl(details, "filesInformationScrollBar");
                if (fittedBar.visible) { console.error("CLIPBOARD UI FAILED: scrollbar must hide when information fits"); Qt.exit(1); return; }
                window.height = 360;
            } else if (step === 27) {
                const details = main.clipboardControl(window.contentItem, "filesColumnDetails");
                const viewport = main.clipboardControl(details, "filesInformationContent");
                const bar = main.clipboardControl(details, "filesInformationScrollBar");
                if (!bar || bar.parent !== details || bar.x < viewport.x + viewport.width) { console.error("CLIPBOARD UI FAILED: information scrollbar overlaps data"); Qt.exit(1); return; }
                const scroll = viewport.contentItem;
                if (!bar.visible) { console.error("CLIPBOARD UI FAILED: scrollbar must appear when information overflows"); Qt.exit(1); return; }
                const end = scroll.contentHeight - scroll.height;
                scroll.contentY = Math.max(0, end);
                if (end <= 0 || scroll.contentY <= 0) { console.error("CLIPBOARD UI FAILED: compact information vertical scroll"); Qt.exit(1); return; }
                const effect = main.clipboardControl(details, "filesScrollEdge");
                scroll.contentY = 0;
                pointerProbe.mouseWheel(viewport, viewport.width / 2, viewport.height / 2, 0, -120, Qt.NoButton, Qt.NoModifier, 0);
                const initial = scroll.contentY;
                pointerProbe.wait(70);
                if (scroll.contentY <= initial || scroll.contentY >= 36) { console.error("CLIPBOARD UI FAILED: wheel scrolling must interpolate smoothly"); Qt.exit(1); return; }
                pointerProbe.wait(200);
                scroll.contentY = end;
                effect.pulse();
                pointerProbe.wait(110);
                const shift = effect.surface.transform[effect.surface.transform.length - 1];
                if (shift.y >= 0 || shift.y < -4) { console.error("CLIPBOARD UI FAILED: subtle end-scroll push"); Qt.exit(1); return; }
                pointerProbe.wait(220);
                if (Math.abs(shift.y) > 0.01) { console.error("CLIPBOARD UI FAILED: end-scroll motion must return without bounce"); Qt.exit(1); return; }
                pointerProbe.mouseWheel(viewport, viewport.width / 2, viewport.height / 2, 0, -120, Qt.NoButton, Qt.NoModifier, 0);
                pointerProbe.wait(70);
                if (shift.y >= 0 || shift.y < -10) { console.error("CLIPBOARD UI FAILED: bounded continued end-scroll push"); Qt.exit(1); return; }
                pointerProbe.wait(350);
                if (Math.abs(shift.y) > 0.01) { console.error("CLIPBOARD UI FAILED: scroll release must settle"); Qt.exit(1); return; }
                if (main.clipboardControl(details, "filesInformationClose")) { console.error("CLIPBOARD UI FAILED: information close button must be removed"); Qt.exit(1); return; }
                window.height = originalHeight;
                controller.viewMode = "list";
                controller.openPlace("computer");
            } else if (step === 28) {
                controller.openEntry({isDirectory: true, url: SOURCE_FOLDER});
            } else if (step === 29) {
                controller.openPlace("desktop");
            } else if (step === 30) {
                const place = main.clipboardControl(window.contentItem, "filesPlace-computer");
                pointerProbe.mouseClick(place, 25, 18, Qt.LeftButton);
            } else if (step === 31) {
                if (controller.directory.location !== SOURCE_FOLDER) { console.error("CLIPBOARD UI FAILED: computer should restore last location"); Qt.exit(1); return; }
                const place = main.clipboardControl(window.contentItem, "filesPlace-computer");
                pointerProbe.mouseDoubleClickSequence(place, 25, 18, Qt.LeftButton);
            } else if (step === 32) {
                if (controller.directory.place !== "computer" || controller.computerLocation !== "pedro:computer") { console.error("CLIPBOARD UI FAILED: double click should reset computer"); Qt.exit(1); return; }
                controller.directory.open(DESTINATION);
                controller.viewMode = "columns";
            } else if (step === 33) {
                const columns = main.clipboardControl(window.contentItem, "filesColumns");
                const column = main.clipboardControl(window.contentItem, "filesDirectoryColumn-0");
                if (!column || column.directory.loading) return;
                columns.contentItem.contentX = 0;
                const name = emptyCycles % 2 ? "context folder" : "nested";
                const row = main.clipboardControl(window.contentItem, "filesColumn-0-" + name);
                if (!row) return;
                pointerProbe.mouseClick(row, 20, 16, Qt.LeftButton);
            } else if (step === 34) {
                const column = main.clipboardControl(window.contentItem, "filesDirectoryColumn-1");
                if (!column || column.directory.loading) return;
                const emptyBar = main.clipboardControl(column, "filesColumnScrollBar");
                if (emptyBar.visible) { console.error("CLIPBOARD UI FAILED: empty-column scrollbar must hide"); Qt.exit(1); return; }
                if (column.directory.count !== 0) { console.error("CLIPBOARD UI FAILED: empty folder fixture"); Qt.exit(1); return; }
                pointerProbe.mouseClick(column, 80, column.height - 40, Qt.LeftButton);
                if (++emptyCycles < 60) { step = 33; return; }
            } else if (step === 35) {
                const column = main.clipboardControl(window.contentItem, "filesDirectoryColumn-0");
                column.openEntry(column.directory.folders.find(entry => entry.name === "Deep"));
            } else if (step === 36) {
                const columns = main.clipboardControl(window.contentItem, "filesColumns");
                const column = main.clipboardControl(window.contentItem, "filesDirectoryColumn-" + (depth + 1));
                if (!column || column.directory.loading) return;
                if (depth < 7) {
                    column.openEntry(column.directory.folders[0]);
                    ++depth;
                    return;
                }
                const scroll = columns.contentItem;
                const end = scroll.contentWidth - scroll.width;
                scroll.contentX = 0;
                if (end <= 0 || scroll.contentX !== 0) { console.error("CLIPBOARD UI FAILED: horizontal column scroll start"); Qt.exit(1); return; }
                scroll.contentX = end;
                if (scroll.contentX !== end) { console.error("CLIPBOARD UI FAILED: horizontal column scroll end"); Qt.exit(1); return; }
                pointerProbe.mouseClick(column, 80, column.height - 40, Qt.LeftButton);
                controller.directory.open(DESTINATION);
            } else if (step === 37) {
                const columns = main.clipboardControl(window.contentItem, "filesColumns");
                if (columns.locations.length !== 1) { console.error("CLIPBOARD UI FAILED: remove nested columns safely"); Qt.exit(1); return; }
                const column = main.clipboardControl(window.contentItem, "filesDirectoryColumn-0");
                if (column.directory.loading) return;
                column.select(column.directory.files.find(entry => entry.name === "drop.txt"));
            } else if (step === 38) {
                const column = main.clipboardControl(window.contentItem, "filesDirectoryColumn-0");
                const details = main.clipboardControl(window.contentItem, "filesColumnDetails");
                if (!details) return;
                const handle = main.clipboardControl(column, "filesColumnResizeHandle");
                const distance = details.width - 140;
                pointerProbe.mousePress(handle, 4, 40, Qt.LeftButton, Qt.NoModifier, 0);
                pointerProbe.mouseMove(handle, 4 + distance, 40, 0, Qt.LeftButton);
                pointerProbe.mouseRelease(handle, 4, 40, Qt.LeftButton, Qt.NoModifier, 0);
            } else if (step === 39) {
                const columns = main.clipboardControl(window.contentItem, "filesColumns");
                if (columns.detailEntry) return;
                const column = main.clipboardControl(window.contentItem, "filesDirectoryColumn-0");
                column.select(column.directory.files.find(entry => entry.name === "drop.txt"));
            } else if (step === 40) {
                const details = main.clipboardControl(window.contentItem, "filesColumnDetails");
                if (!details || details.width < 260) { console.error("CLIPBOARD UI FAILED: information must reopen after collapse"); Qt.exit(1); return; }
                console.log("CLIPBOARD UI PASSED: information collapse/reopen, smooth scrolling, deep columns and empty folders");
                Qt.quit();
            }
            ++step;
            } finally { executing = false; }
        }
    }
'''
for key, value in {'DESKTOP': (fixtures / 'desktop').as_uri(), 'DESTINATION': (fixtures / 'destination').as_uri(), 'SOURCE_FILE': (fixtures / 'source' / 'shared.txt').as_uri(), 'SOURCE_FOLDER': (fixtures / 'source').as_uri(), 'CAPTURE_PATH': str(target / 'information.png')}.items():
    actions = actions.replace(key, json.dumps(value))
position = source.rfind('}')
(target / 'Main.qml').write_text(source[:position] + actions + source[position:])
environment = dict(os.environ, PEDRO_DEVELOPMENT_MODE='1', PEDRO_QML_DIR=str(target),
                   QT_QPA_PLATFORM=os.environ.get('PEDRO_UI_TEST_PLATFORM', 'offscreen'), QT_QUICK_BACKEND=os.environ.get('QT_QUICK_BACKEND', 'software'), QT_QPA_PLATFORMTHEME='none')
command = [str(root / 'build/dev/gui/pedro-gui')]
if os.environ.get('PEDRO_UI_TEST_DEBUG'):
    command = ['gdb', '-batch', '-ex', 'run', '-ex', 'thread apply all bt', '--args'] + command
result = subprocess.run(command, env=environment,
                        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=120)
(target / 'check.log').write_text(result.stdout)
if result.returncode or 'CLIPBOARD UI PASSED' not in result.stdout or any(error in result.stdout for error in ('ReferenceError', 'TypeError', 'Binding loop detected', 'Failed to get image from provider', 'cannot show menu: parent is null', 'CLIPBOARD UI FAILED')):
    raise SystemExit(result.stdout)
assert (fixtures / 'source' / 'shared (2).txt').read_text() == 'shared clipboard fixture\n'
assert (fixtures / 'destination' / 'renamed fixture.txt').read_text() == 'shared clipboard fixture\n'
assert (fixtures / 'destination' / 'clicked away.txt').read_text() == 'shared clipboard fixture\n'
assert not (fixtures / 'destination' / 'cancelled.txt').exists()
assert (fixtures / 'destination' / 'context folder').is_dir()
assert (fixtures / 'destination' / 'context.txt').is_file()
assert (fixtures / 'destination' / 'drop.txt').read_text() == 'Shared drop fixture\n'
assert not (fixtures / 'desktop' / 'drop.txt').exists()
assert not (fixtures / 'source' / 'drop.txt').exists()
assert not (fixtures / 'destination' / 'viewer.txt').exists()
assert not (fixtures / 'destination' / 'viewer renamed.txt').exists()
assert (fixtures / 'source' / 'viewer renamed.txt').read_text() == 'Saved after move\n'
print('PASS: shared drag input, location drops, all view context menus and preview tracking')
