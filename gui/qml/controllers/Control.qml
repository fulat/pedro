import QtQuick
import gui

// Coordinates actions emitted by the control-center presentation.
QtObject {
    required property var view
    property string notice: Papi.wifiError !== "" ? Papi.wifiError : qsTranslate("Pedro", "shell.status.wifiConnected")

    // Changes Wi-Fi state through PAPI.
    function setWifiEnabled(state) {
        Papi.setWifiEnabled(state);
    }

    // Requests the detailed Wi-Fi view.
    function requestWifi() {
        view.wifiRequested();
    }

    // Changes Bluetooth state through PAPI.
    function setBluetoothEnabled(state) {
        Papi.setBluetoothEnabled(state);
    }

    // Requests the detailed Bluetooth view.
    function requestBluetooth() {
        view.bluetoothRequested();
    }

    // Requests the system settings view.
    function requestSettings() {
        view.settingsRequested();
    }

    // Updates the informational notice shown by the control center.
    function showNotice(message) {
        notice = message;
    }
}
