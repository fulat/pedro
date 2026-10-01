import QtQuick
import gui

// Owns application favorite changes requested from the dock.
QtObject {

    // Adds or removes one installed application from GNOME favorites.
    function setPinned(application, pinned) {
        if (!application || !application.id) {
            return;
        }

        Papi.setApplicationPinned(application.id, pinned);
    }
}
