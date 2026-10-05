import QtQuick

// File behavior is independent of its presentation. Hosts supply selection and navigation.
QtObject {
    property var entry: ({})
    property var owner: null
    property var window: null
    property var renameDialog: null
    signal requested(string action, var entry)

    function entries(value = entry) {
        return owner && owner.contextEntries ? owner.contextEntries(value) : [value];
    }

    function select(contextMenu = false) {
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
            if (Backend.fileTransfer.busy) return;
            if (renameDialog && renameDialog.visible) { renameDialog.activateAlert(); return; }
            const component = Qt.createComponent("../../components/entry/rename.qml");
            const dialog = component.createObject(window || owner, {entry: value, ownerWindow: window});
            if (dialog) {
                renameDialog = dialog;
                dialog.visibleChanged.connect(() => { if (!dialog.visible) renameDialog = null; });
                dialog.open();
            }
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
        } else if (action === "open" && value.isDirectory && window && window.openFolderWindow) {
            window.openFolderWindow(value.url);
        } else if ((action === "open" || action === "preview") && !value.isDirectory && value.url) {
            Backend.openPreview(value.inTrash ? value.targetUrl : value.url, [], true, !!value.inTrash);
        } else {
            requested(action, value);
        }
    }
}
