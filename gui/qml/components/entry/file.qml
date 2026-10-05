pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window

Loader {
    id: root
    property var controller: null
    property var entry: ({})
    readonly property bool cutPending: !!item && item.cutPending
    property bool showName: true
    property Item nameSurface: null
    property string label: entry.name || ""
    property int nameAlignment: Text.AlignHCenter
    property int nameSize: 12
    property int nameWeight: Font.Medium
    readonly property bool renaming: !!item && item.renaming
    readonly property var nameEditor: item ? item.nameEditor : null
    property bool inputEnabled: true
    property Item inputSurface: null
    property bool activateOnClick: false
    property real iconSize: 64
    property color textColor: "white"
    property Item backdrop: Window.window ? Window.window.entryBackdrop || null : null
    signal actionRequested(string action)
    signal contextRequested()
    signal navigationRequested(string action, var entry)
    source: "item.qml"
    function beginRename() { if (item) item.beginRename(); }
    function closeMenu() { if (item && item.menu) item.menu.close(); }
    function select() { if (item) item.select(); }
    function activate() { if (item) item.activate(); }
    function openMenu(x, y) { if (item) item.openMenu(x, y); }
    function dispatch(action) { if (item) item.dispatch(action); }
    function dragFiles(source = root, urls = undefined) { return item ? item.dragFiles(source, urls) : Qt.IgnoreAction; }
    function canDrop(urls) { return item && item.canDrop(urls); }
    function dropFiles(urls) { return item && item.dropFiles(urls); }
    onLoaded: {
        item.folder = false;
        item.controller = Qt.binding(() => root.controller);
        item.entry = Qt.binding(() => root.entry);
        item.showName = Qt.binding(() => root.showName);
        item.nameSurface = Qt.binding(() => root.nameSurface);
        item.label = Qt.binding(() => root.label);
        item.nameAlignment = Qt.binding(() => root.nameAlignment);
        item.nameSize = Qt.binding(() => root.nameSize);
        item.nameWeight = Qt.binding(() => root.nameWeight);
        item.inputEnabled = Qt.binding(() => root.inputEnabled);
        item.inputSurface = Qt.binding(() => root.inputSurface || item);
        item.activateOnClick = Qt.binding(() => root.activateOnClick);
        item.iconSize = Qt.binding(() => root.iconSize);
        item.textColor = Qt.binding(() => root.textColor);
        item.backdrop = Qt.binding(() => root.backdrop);
        item.actionRequested.connect(action => root.actionRequested(action));
        item.contextRequested.connect(() => root.contextRequested());
        item.navigationRequested.connect((action, entry) => root.navigationRequested(action, entry));
    }
}
