pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import "../desktop" as Desktop

Item {
    id: entryItem
    objectName: "entryComponent-" + (entry.name || "")
    readonly property var menu: menuLoader.item
    property var controller
    property var entry: ({})
    property bool folder: false
    property bool showName: true
    property bool inputEnabled: true
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
            item.entry = Qt.binding(() => entryItem.entry);
            item.owner = Qt.binding(() => entryItem.controller);
        }
    }

    function select() {
        if (interaction.item) interaction.item.select();
    }

    function activate() {
        if (interaction.item) interaction.item.activate();
    }

    function openMenu(x, y) {
        if (!Window.window) {
            return;
        }
        select();
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
        menu.folderName = entry.name || "";
        menu.fileMode = !folder;
        menu.imageFile = entry.icon === "image";
        menu.popup(menuPoint.x, menuPoint.y);
    }

    Desktop.Icon {
        width: entryItem.iconSize
        height: width
        anchors.horizontalCenter: parent.horizontalCenter
        y: entryItem.showName ? 8 : (parent.height - height) / 2
        kind: entryItem.folder ? "folder" : entryItem.entry.icon === "image" && String(entryItem.entry.url || "").startsWith("file:") ? "image" : "notes"
        imageUrl: entryItem.entry.url || ""
        cornerRadius: entryItem.cornerRadius
    }
    Text {
        visible: entryItem.showName
        y: entryItem.iconSize + 13
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 6
        text: entryItem.entry.name || ""
        color: entryItem.textColor
        horizontalAlignment: Text.AlignHCenter
        font.pixelSize: 12
        elide: Text.ElideMiddle
    }
    MouseArea {
        anchors.fill: parent
        enabled: entryItem.inputEnabled
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) entryItem.openMenu(mouse.x, mouse.y);
            else entryItem.select();
        }
        onDoubleClicked: mouse => {
            if (mouse.button === Qt.LeftButton) entryItem.activate();
        }
    }
    Loader {
        id: menuLoader
        active: false
        source: "menu.qml"
        onLoaded: {
            item.objectName = "entryMenu";
            item.parent = entryItem.Window.window.contentItem;
            item.backdrop = Qt.binding(() => entryItem.backdrop);
            item.maximumHeight = Qt.binding(() => entryItem.Screen.desktopAvailableHeight > 0 ? entryItem.Screen.desktopAvailableHeight - 16 : 600);
            item.actionRequested.connect(action => {
                if (interaction.item) interaction.item.dispatch(action);
                entryItem.actionRequested(action);
            });
            Qt.callLater(entryItem.showMenu);
        }
    }
}
