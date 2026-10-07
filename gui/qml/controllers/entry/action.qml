import QtQuick
import "registry.js" as Registry

// File behavior is independent of its presentation. Hosts supply selection and navigation.
QtObject {
    property var entry: ({})
    property var owner: null
    property var window: null
    property var component: null
    signal requested(string action, var entry)

    function entries(value = entry) {
        return owner && owner.contextEntries ? owner.contextEntries(value) : [value];
    }

    function select(contextMenu = false, pointerPress = false) {
        if (pointerPress && owner && owner.selectForDrag) {
            owner.selectForDrag(entry);
            return;
        }
        if (owner && owner.select) owner.select(entry, contextMenu);
    }

    function activate() {
        dispatch("open");
    }

    function canDrop(urls, destination = entry.url) {
        return !entry.inTrash && Backend.fileTransfer.canMove(urls, destination);
    }

    function drop(urls, destination = entry.url) {
        if (!canDrop(urls, destination)) return false;
        Backend.fileTransfer.move(urls, destination);
        return true;
    }

    function drag(source, urls = entries().map(item => item.url)) {
        if (entry.inTrash || !urls.length) return Qt.IgnoreAction;
        return Backend.dragFiles(source, urls);
    }

    function dispatch(action, value = entry) {
        const selection = entries(value);
        const urls = selection.map(item => item.url).filter(url => !!url);
        if (action === "copy" || action === "cut") {
            Backend.clipboard.copy(urls, action === "cut");
        } else if (action === "duplicate" && !value.inTrash) {
            if (selection.length === 1) Backend.fileTransfer.duplicate(value.url);
        } else if (action === "rename" && !value.inTrash && selection.length === 1) {
            const target = component && String(component.entry.url) === String(value.url) ? component : Registry.find(window, value.url);
            if (target) target.beginRename();
        } else if (action === "paste") {
            Backend.clipboard.paste(value.isDirectory ? value.url : owner && owner.directory ? (owner.directory.location || owner.directory.directory) : "");
        } else if (action === "trash") {
            Backend.trash.move(urls);
        } else if (action === "restore") {
            Backend.trash.restore(urls);
        } else if (owner && owner.handleEntryAction) {
            owner.handleEntryAction(action, value);
        } else if (action === "open" && owner && owner.openEntry) {
            owner.openEntry(value);
        } else if (action === "properties" && window && window.openInformationWindow) {
            window.openInformationWindow(value);
        } else if (action === "open" && value.isDirectory && window && window.openFolderWindow) {
            window.openFolderWindow(value.url);
        } else if ((action === "open" || action === "preview") && !value.isDirectory && value.url) {
            Backend.openPreview(value.inTrash ? value.targetUrl : value.url, [], true, !!value.inTrash);
        } else {
            requested(action, value);
        }
    }
}
