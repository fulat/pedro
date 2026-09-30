import QtQuick

// Owns interaction behavior for a generic toggle tile.
QtObject {
    required property var view

    // Toggles mutable state and then announces the activation.
    function activate() {
        if (view.toggleable) {
            view.active = !view.active;
        }

        view.activated();
    }
}
