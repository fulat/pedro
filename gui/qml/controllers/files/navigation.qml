import QtQuick
import Pedro.Files 1.0

// One instance per Files window. PAPI owns paths, listing and filesystem events.
QtObject {
    id: controller
    objectName: "filesController"
    property bool sidebarCollapsed: false
    property string activePlace: directory ? directory.place : ""
    property string viewMode: "grid"
    property string sortKey: "type"
    onSortKeyChanged: { if (directory) directory.setSort(sortKey); }
    property var directory: null
    onDirectoryChanged: { if (directory) directory.setSort(sortKey); }
    property var window: null
    property var selectedEntry: ({})
    property var selectedEntries: []
    property string selectionDirectory: ""
    property var selectionModel: directory
    onViewModeChanged: { if (directory && selectionModel !== directory) clearSelection(directory); }
    readonly property var currentTag: {
        const revision = Tags.revision;
        return directory && String(directory.location).startsWith("pedro:tag:") ? Tags.definition(String(directory.location).slice(10)) : ({});
    }
    readonly property string title: currentTag.name || (directory && directory.globalSearch && directory.search.trim().length ? qsTranslate("Pedro", "files.browser.searchResults") : directory ? directory.place.length ? qsTranslate("Pedro", "files.browser." + directory.place) : directory.name || qsTranslate("Pedro", "files.browser.computer") : "")
    readonly property var folders: directory ? directory.folders : []
    readonly property var files: directory ? directory.files : []

    property Connections selectionConnection: Connections {
        target: controller.directory || null
        function onLocationChanged() { controller.activePlace = controller.directory.place; controller.directory.search = ""; controller.clearSelection(); }
        function onSearchChanged() { controller.clearSelection(); }
        function onContentsChanged() { controller.refreshSelection(controller.directory); }
    }

    function containsEntry(item, point) {
        for (const child of item.children) {
            if (!child.visible) {
                continue;
            }
            const local = item.mapToItem(child, point.x, point.y);
            if (child.clip && !child.contains(local)) {
                continue;
            }
            if (child.entry !== undefined && child.entry.id && child.contains(local)) {
                return true;
            }
            if (containsEntry(child, local)) {
                return true;
            }
        }
        return false;
    }

    function openPlace(place) {
        activePlace = place;
        clearSelection();
        directory.openPlace(place);
    }

    function openTag(id) {
        activePlace = "";
        clearSelection();
        directory.open("pedro:tag:" + id);
    }

    function resetPlace(place) {
        openPlace(place);
    }

    function clearSelection(target = directory) {
        selectionModel = target;
        selectedEntries = [];
        selectedEntry = {};
        selectionDirectory = "";
    }

    function isSelected(entry) {
        return selectedEntries.some(value => value.id === entry.id);
    }

    function contextEntries(entry) {
        return isSelected(entry) ? selectedEntries : [entry];
    }

    function select(entry, contextMenu = false, target = directory) {
        if (contextMenu && isSelected(entry)) return;
        selectedEntries = [entry];
        selectedEntry = entry;
        selectionModel = target;
        selectionDirectory = target ? String(target.location) : "";
    }

    function selectAll(target = selectionModel || directory) {
        selectedEntries = target ? target.folders.concat(target.files) : [];
        selectedEntry = selectedEntries.length ? selectedEntries[0] : {};
        selectionModel = target;
        selectionDirectory = target ? String(target.location) : "";
    }

    function refreshSelection(target) {
        if (!target || target.loading || selectionDirectory !== String(target.location)) return;
        const entries = target.folders.concat(target.files);
        selectedEntries = selectedEntries.map(value => entries.find(entry => entry.id === value.id)).filter(value => !!value);
        selectedEntry = selectedEntries.find(value => value.id === selectedEntry.id) || selectedEntries[0] || {};
    }

    signal emptyRequested()
    signal moveRequested(var entry)
    signal informationRequested(var entry)
    signal removalRequested(var urls)

    property var fileBehavior: null
    Component.onCompleted: {
        const component = Qt.createComponent("../entry/action.qml");
        fileBehavior = component.createObject(controller, {owner: controller});
        fileBehavior.window = Qt.binding(() => controller.window);
    }

    function entryAction(action, entry) {
        fileBehavior.dispatch(action, entry);
    }

    function handleEntryAction(action, entry) {
        if (action === "select") selectAll();
        else if (action === "remove" && entry.canRemove) removalRequested([entry.url]);
        else if (action === "open") openEntry(entry);
        else if (action === "preview") previewEntry(entry);
        else if (action === "relocate" && entry.canRemove) moveRequested(entry);
        else if (action === "properties") informationRequested(entry);
    }

    function openEntry(entry) {
        if (entry.isDirectory) {
            clearSelection();
            directory.open(entry.url);
        } else if (entry.url) {
            previewEntry(entry);
        }
    }

    function previewEntry(entry) {
        if (entry && entry.url && !entry.isDirectory && (!entry.inTrash || entry.targetUrl)) {
            Backend.openPreview(entry.inTrash ? entry.targetUrl : entry.url, entry.inTrash ? [] : files.map(item => item.url), true, !!entry.inTrash);
        }
    }

    function back() {
        clearSelection();
        directory.goBack();
    }

    function forward() {
        clearSelection();
        directory.goForward();
    }
}
