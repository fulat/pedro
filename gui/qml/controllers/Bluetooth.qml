import QtQuick
import gui

// Coordinates Bluetooth refresh and delayed scan behavior for its view.
QtObject {
    id: controller

    required property var view
    property bool scanAfterRefresh: false

    // Refreshes Bluetooth whenever the view becomes visible.
    function visibilityChanged(visible) {
        if (!visible) {
            return;
        }

        scanAfterRefresh = true;
        Papi.refreshBluetooth();
    }

    // Starts scanning after the requested refresh exposes usable hardware.
    function bluetoothChanged() {
        if (!scanAfterRefresh) {
            return;
        }

        scanAfterRefresh = false;

        if (view.visible && Papi.bluetoothAvailable && Papi.bluetoothEnabled) {
            Papi.scanBluetooth();
        }
    }

    // Listens to backend state changes without placing handlers in the view.
    property Connections backendConnections: Connections {
        target: Papi
        function onBluetoothChanged() {
            controller.bluetoothChanged();
        }
    }
}
