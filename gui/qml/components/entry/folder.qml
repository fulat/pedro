pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window

Loader {
    id: root
    property var controller
    property var entry: ({})
    readonly property bool cutPending: !!item && item.cutPending
    property bool showName: true
    property bool inputEnabled: true
    property real iconSize: 64
    property color textColor: "white"
    property Item backdrop: Window.window ? Window.window.entryBackdrop || null : null
    signal actionRequested(string action)
    signal contextRequested()
    source: "item.qml"
    function closeMenu() { if (item && item.menu) item.menu.close(); }
    function select() { if (item) item.select(); }
    function activate() { if (item) item.activate(); }
    function openMenu(x, y) { if (item) item.openMenu(x, y); }
    onLoaded: {
        item.folder = true;
        item.controller = Qt.binding(() => root.controller);
        item.entry = Qt.binding(() => root.entry);
        item.showName = Qt.binding(() => root.showName);
        item.inputEnabled = Qt.binding(() => root.inputEnabled);
        item.iconSize = Qt.binding(() => root.iconSize);
        item.textColor = Qt.binding(() => root.textColor);
        item.backdrop = Qt.binding(() => root.backdrop);
        item.actionRequested.connect(action => root.actionRequested(action));
        item.contextRequested.connect(() => root.contextRequested());
    }
}
