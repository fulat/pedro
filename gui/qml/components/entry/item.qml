pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import "../desktop" as Desktop
import "../icon" as Icon
import "../../scripts/theme.js" as Theme
import "../../controllers/entry/registry.js" as Registry

Item {
    id: entryItem
    objectName: "entryComponent-" + (entry.name || "")
    readonly property var menu: menuLoader.item
    property var controller: null
    property var entry: ({})
    readonly property bool cutPending: Backend.clipboard.cutFiles.length > 0 && Backend.clipboard.isCut(entry.url || "")
    property bool folder: false
    property bool showName: true
    property Item nameSurface: null
    property string label: entry.name || ""
    property int nameAlignment: Text.AlignHCenter
    property int nameSize: 12
    property bool nameBold: false
    property bool renaming: false
    property url renameSource
    readonly property var nameEditor: nameLoader.item ? nameLoader.item.editor : null
    readonly property var registeredWindow: Window.window
    Component.onCompleted: Registry.register(entryItem)
    Component.onDestruction: Registry.unregister(entryItem)
    property bool inputEnabled: true
    property Item inputSurface: entryItem
    property bool activateOnClick: false
    property bool keyboardEnabled: !controller
    signal navigationRequested(string action, var entry)
    property real iconSize: 64
    property real cornerRadius: iconSize < 40 ? 2 : 5
    property color textColor: "white"
    property Item backdrop: Window.window ? Window.window.entryBackdrop || null : null
    property point menuPoint
    signal actionRequested(string action)
    signal contextRequested()

    Loader {
        id: interaction
        source: "../../controllers/entry/action.qml"
        onLoaded: {
            item.entry = Qt.binding(() => Object.assign({}, entryItem.entry, {isDirectory: entryItem.folder}));
            item.owner = Qt.binding(() => entryItem.controller);
            item.window = Qt.binding(() => entryItem.Window.window);
            item.component = entryItem;
            item.requested.connect((action, entry) => entryItem.navigationRequested(action, entry));
        }
    }

    function select() {
        if (interaction.item) interaction.item.select();
    }

    function activate() {
        if (interaction.item) interaction.item.activate();
    }

    function dispatch(action) {
        if (interaction.item) interaction.item.dispatch(action);
    }

    function dragFiles(source = entryItem, urls = undefined) {
        return interaction.item ? interaction.item.drag(source, urls) : Qt.IgnoreAction;
    }

    function canDrop(urls) {
        return interaction.item && interaction.item.canDrop(urls);
    }

    function dropFiles(urls) {
        return interaction.item && interaction.item.drop(urls);
    }

    function beginRename() {
        if (entry.inTrash || Backend.fileTransfer.busy || !nameEditor) return;
        renameSource = entry.url;
        renaming = true;
        nameEditor.text = entry.editName || entry.name || "";
        Qt.callLater(() => {
            if (!renaming) return;
            nameEditor.forceActiveFocus();
            const dot = nameEditor.text.lastIndexOf(".");
            nameEditor.select(0, !folder && dot > 0 ? dot : nameEditor.text.length);
        });
    }

    function cancelRename() {
        renaming = false;
    }

    function finishRename(keepInvalid = true) {
        if (!renaming) return;
        const text = nameEditor.text;
        if (!Backend.fileTransfer.validName(text) || Backend.fileTransfer.busy) {
            if (keepInvalid) nameEditor.forceActiveFocus();
            else cancelRename();
            return;
        }
        renaming = false;
        if (text !== (entry.editName || entry.name)) Backend.fileTransfer.rename(renameSource, text);
    }

    Connections {
        target: entryItem.registeredWindow
        function onActiveChanged() {
            if (!entryItem.registeredWindow.active && entryItem.renaming) entryItem.finishRename(false);
        }
    }

    TapHandler {
        parent: entryItem.registeredWindow ? entryItem.registeredWindow.contentItem : entryItem
        enabled: entryItem.renaming
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onTapped: point => {
            const local = parent.mapToItem(entryItem.nameEditor, point.position.x, point.position.y);
            if (!entryItem.nameEditor.contains(local)) entryItem.finishRename(false);
        }
    }

    function openMenu(x, y) {
        if (!Window.window) {
            return;
        }
        if (interaction.item) interaction.item.select(true);
        contextRequested();
        menuPoint = mapToItem(Window.window.contentItem, x, y);
        if (menuLoader.item) {
            showMenu();
        } else {
            menuLoader.active = true;
        }
    }

    function showMenu() {
        const menu = menuLoader.item;
        const window = Window.window;
        if (!window || !menu) {
            return;
        }
        menu.selectionCount = controller && controller.contextEntries ? controller.contextEntries(entry).length : 1;
        menu.canCut = Qt.binding(() => {
            const pending = Backend.clipboard.cutFiles;
            const entries = controller && controller.contextEntries ? controller.contextEntries(entry) : [entry];
            return Backend.clipboard.canCut(entries.map(item => item.url));
        });
        menu.canPaste = Qt.binding(() => Backend.clipboard.canPaste && Backend.clipboard.canPasteInto(entryItem.entry.url || ""));
        menu.folderName = entry.name || "";
        menu.fileMode = !folder;
        menu.imageFile = entry.icon === "image";
        if (entry.inTrash) {
            menu.canRestore = !!entry.canRestore;
            menu.canRemove = !!entry.canRemove;
            menu.canRead = !!entry.targetUrl;
        }
        menu.popup(menuPoint.x, menuPoint.y);
    }

    DropArea {
        parent: entryItem.inputSurface
        anchors.fill: parent
        enabled: entryItem.folder && !entryItem.entry.inTrash
        keys: ["text/uri-list"]
        onEntered: drag => { drag.accepted = entryItem.canDrop(drag.urls); }
        onDropped: drop => {
            if (entryItem.dropFiles(drop.urls)) {
                drop.accept(Qt.MoveAction);
            }
        }
        Rectangle {
            anchors.fill: parent
            visible: parent.containsDrag
            radius: 8
            color: "#305b99dd"
            border.color: "#805b99dd"
        }
    }

    Desktop.Icon {
        id: fileIcon
        opacity: entryItem.cutPending ? Theme.cutOpacity : 1
        width: entryItem.iconSize
        height: width
        anchors.horizontalCenter: parent.horizontalCenter
        y: entryItem.showName ? 8 : (parent.height - height) / 2
        kind: entryItem.folder ? "folder" : entryItem.entry.visualType || "notes"
        iconNames: entryItem.entry.iconNames || []
        imageUrl: entryItem.entry.url || ""
        revision: entryItem.entry.modified || 0
        cornerRadius: entryItem.cornerRadius
    }
    Icon.Tinted {
        objectName: "cutBadge"
        visible: entryItem.cutPending
        anchors.centerIn: fileIcon
        width: Math.max(16, Math.min(36, entryItem.iconSize * 0.65))
        height: width
        source: "../../../assets/icons/cut.svg"
        tint: "#b8bec7"
        opacity: 0.85
    }
    Item {
        id: defaultNameSurface
        y: entryItem.iconSize + 10
        width: entryItem.width
        height: 30
        z: 5
        visible: entryItem.showName || entryItem.renaming
    }
    Loader {
        id: nameLoader
        parent: entryItem.nameSurface || defaultNameSurface
        anchors.fill: parent
        z: 5
        source: "name.qml"
        onLoaded: item.behavior = entryItem
    }
    MouseArea {
        parent: entryItem.inputSurface
        property point origin
        property bool dragged: false
        anchors.fill: parent
        enabled: entryItem.inputEnabled
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => {
            origin = Qt.point(mouse.x, mouse.y);
            dragged = false;
            if (mouse.button === Qt.LeftButton) {
                if (entryItem.keyboardEnabled) entryItem.forceActiveFocus();
                entryItem.select();
            }
        }
        onPositionChanged: mouse => {
            if (!(pressedButtons & Qt.LeftButton) || dragged) return;
            const distance = Math.hypot(mouse.x - origin.x, mouse.y - origin.y);
            if (distance < Qt.styleHints.startDragDistance) return;
            dragged = true;
            entryItem.dragFiles();
        }
        onClicked: mouse => {
            if (dragged) return;
            if (mouse.button === Qt.RightButton) {
                const point = mapToItem(entryItem, mouse.x, mouse.y);
                entryItem.openMenu(point.x, point.y);
            }
            else if (entryItem.activateOnClick) entryItem.activate();
            else entryItem.select();
        }
        onDoubleClicked: mouse => {
            if (!dragged && !entryItem.activateOnClick && mouse.button === Qt.LeftButton) entryItem.activate();
        }
    }
    Loader {
        active: entryItem.keyboardEnabled
        source: "shortcuts.qml"
        onLoaded: {
            item.entries = Qt.binding(() => entryItem.activeFocus ? [entryItem.entry] : []);
            item.destination = Qt.binding(() => entryItem.folder ? entryItem.entry.url : "");
            item.enabledForView = Qt.binding(() => entryItem.activeFocus);
            item.actionRequested.connect(action => entryItem.dispatch(action));
        }
    }
    Loader {
        id: menuLoader
        active: false
        source: entryItem.entry.inTrash ? "trash.qml" : "menu.qml"
        onLoaded: {
            item.objectName = "entryMenu";
            item.parent = entryItem.Window.window.contentItem;
            item.backdrop = Qt.binding(() => entryItem.backdrop);
            item.maximumHeight = Qt.binding(() => entryItem.Screen.desktopAvailableHeight > 0 ? entryItem.Screen.desktopAvailableHeight - 16 : 600);
            item.actionRequested.connect(action => {
                if (interaction.item) interaction.item.dispatch(action);
                entryItem.actionRequested(action);
            });
            entryItem.showMenu();
        }
    }
}
