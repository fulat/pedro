import QtQuick
import gui

// Coordinates Wi-Fi refresh and scan requests for the Wi-Fi view.
QtObject {

    // Scans when the Wi-Fi view becomes visible and networking is available.
    function visibilityChanged(visible) {
        if (visible && Papi.wifiAvailable && Papi.wifiEnabled) {
            Papi.scanWifi();
        }
    }

    // Chooses between a scan and a state refresh for the scan button.
    function scanRequested() {
        if (Papi.wifiAvailable && Papi.wifiEnabled) {
            Papi.scanWifi();
        } else {
            Papi.refreshWifi();
        }
    }
}
