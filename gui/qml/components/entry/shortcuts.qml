pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window

Item {
    id: shortcuts
    property var entries: []
    property url destination
    property bool enabledForView: true
    property bool pasteEnabled: true
    signal actionRequested(string action)
    readonly property var window: Window.window
    readonly property bool available: enabledForView && window && window.active
        && !(window.activeFocusItem && window.activeFocusItem.selectedText !== undefined)
    readonly property var urls: entries.map(entry => entry.url).filter(url => !!url)
    readonly property bool canCut: {
        const pending = Backend.clipboard.cutFiles;
        return available && urls.length > 0 && !entries.some(entry => entry.inTrash) && Backend.clipboard.canCut(urls);
    }

    Shortcut {
        context: Qt.WindowShortcut
        sequence: "Ctrl+C"
        enabled: shortcuts.available && shortcuts.urls.length > 0
        onActivated: shortcuts.actionRequested("copy")
    }
    Shortcut {
        context: Qt.WindowShortcut
        sequence: "Ctrl+X"
        enabled: shortcuts.canCut
        onActivated: shortcuts.actionRequested("cut")
    }
    Shortcut {
        context: Qt.WindowShortcut
        sequence: "Ctrl+V"
        enabled: shortcuts.available && shortcuts.pasteEnabled && Backend.clipboard.canPaste && Backend.clipboard.canPasteInto(shortcuts.destination)
        onActivated: Backend.clipboard.paste(shortcuts.destination)
    }
    Shortcut {
        context: Qt.WindowShortcut
        sequence: "Space"
        enabled: shortcuts.available && shortcuts.entries.length === 1 && !shortcuts.entries[0].isDirectory && !shortcuts.entries[0].inTrash
        onActivated: shortcuts.actionRequested("preview")
    }
    Shortcut {
        context: Qt.WindowShortcut
        sequence: "Delete"
        enabled: shortcuts.available && shortcuts.urls.length > 0 && !Backend.trash.busy
        onActivated: shortcuts.actionRequested(shortcuts.entries[0].inTrash ? "remove" : "trash")
    }
}
