import QtQuick

// Shared interaction policy; the host owns selection and navigation state.
QtObject {
    property var entry
    property var owner

    function select() {
        if (owner) {
            owner.select(entry);
        }
    }

    function activate() {
        if (owner) {
            owner.openEntry(entry);
        }
    }

    function dispatch(action) {
        if (action === "open") {
            activate();
        }
    }
}
