import QtQuick

// One instance per Files window. PAPI owns paths, listing and filesystem events.
QtObject {
    id: controller
    objectName: "filesController"
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

    function openPlace(place) {
        selectedEntry = {};
        directory.openPlace(place);
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
