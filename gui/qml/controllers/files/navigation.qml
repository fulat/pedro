import QtQuick

// One instance per Files window. PAPI owns paths, listing and filesystem events.
QtObject {
    id: controller
    objectName: "filesController"
    property bool sidebarCollapsed: false
    property string viewMode: "mixed"
    property string sortKey: "name"
    onSortKeyChanged: { if (directory) directory.setSort(sortKey); }
    property var directory: null
    property var selectedEntry: ({})
    readonly property string title: directory ? directory.place.length ? qsTranslate("Pedro", "files.browser." + directory.place) : directory.name || qsTranslate("Pedro", "files.browser.computer") : ""
    readonly property var folders: directory ? directory.folders : []
    readonly property var files: directory ? directory.files : []

    property Connections selectionConnection: Connections {
        target: controller.directory || null
        function onContentsChanged() {
            if (!controller.selectedEntry.id) {
                return;
            }
            const entry = controller.folders.concat(controller.files).find(item => item.id === controller.selectedEntry.id);
            if (entry) {
                controller.selectedEntry = entry;
            } else if (!controller.directory.loading) {
                controller.selectedEntry = {};
            }
        }
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
        selectedEntry = {};
        directory.openPlace(place);
    }

    function clearSelection() {
        selectedEntry = {};
    }

    function select(entry) {
        selectedEntry = entry;
    }

    function openEntry(entry) {
        if (entry.isDirectory) {
            selectedEntry = {};
            directory.open(entry.url);
        }
    }

    function back() {
        selectedEntry = {};
        directory.goBack();
    }

    function forward() {
        selectedEntry = {};
        directory.goForward();
    }
}
