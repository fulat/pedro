import QtQuick
import gui

// Coordinates desktop application launch and favorite changes through PAPI.
QtObject {

    function launchApplication(application) {
        if (!application || !application.id) {
            return;
        }

        Papi.launchApplication(application.id);
    }

    // Adds or removes one installed application from GNOME favorites.
    function setPinned(application, pinned) {
        if (!application || !application.id) {
            return;
        }

        Papi.setApplicationPinned(application.id, pinned);
    }
}
