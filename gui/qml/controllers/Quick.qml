import QtQuick

// Owns interaction behavior for a quick-settings tile.
QtObject {
    required property var view

    // Applies a toggle request while respecting externally managed state.
    function setActive(state) {
        if (!view.toggleable) {
            return;
        }

        if (!view.externallyManaged) {
            view.active = state;
        }

        view.toggleRequested(state);
    }

    // Emits the semantic actions associated with pressing the tile body.
    function activate() {
        view.detailsRequested();
        view.activated();
    }
}
