pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window

Loader {
    id: root
    property var entry: ({})
    property bool showName: true
    property bool inputEnabled: true
    property real iconSize: 64
    property color textColor: "white"
    property Item backdrop: Window.window ? Window.window.entryBackdrop || null : null
    signal actionRequested(string action)
    signal contextRequested()
    source: "item.qml"
    function openMenu(x, y) { if (item) item.openMenu(x, y); }
    onLoaded: {
        item.folder = false;
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
