import QtQuick
import QtQuick.Layouts
import gui
import "../../controllers" as Controllers
import "../media" as Media
import "../quick" as Quick
import "../slider" as Slider
import "../toggle" as Toggle
import "../../scripts/theme.js" as Theme

Item {
    id: root
    implicitHeight: content.implicitHeight
    property alias notice: controller.notice
    readonly property bool wifiEnabled: Papi.wifiEnabled
    readonly property bool wifiConnected: Papi.wifiConnected
    signal settingsRequested
    signal wifiRequested
    signal captureRequested
    signal keyboardRequested
    signal bluetoothRequested

    // Connects control-center actions to backend and navigation behavior.
    Controllers.Control {
        id: controller
        view: root
    }

    Connections {
        target: Papi.powerSaving
        function onChanged() {
            if (Papi.powerSaving.error.length > 0)
                controller.showNotice(Papi.powerSaving.error);
        }
    }

    Connections {
        target: Papi.focusMode
        function onChanged() {
            if (Papi.focusMode.error.length > 0)
                controller.showNotice(Papi.focusMode.error);
        }
    }

    Connections {
        target: Papi.nightLight
        function onChanged() {
            if (Papi.nightLight.error.length > 0)
                controller.showNotice(Papi.nightLight.error);
        }
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        spacing: 4

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Quick.Tile {
                id: wifiTile
                title: Papi.networkConnection.type === "ethernet" ? "Ethernet" : Papi.networkConnection.type === "wifi" || (Papi.networkConnection.type === "none" && Papi.wifiAvailable) ? qsTranslate("Pedro", "network.wifi.title") : qsTranslate("Pedro", "network.connection.title")
                icon: Papi.networkConnection.type === "ethernet" ? "../../../assets/icons/ethernet.svg" : "../../../assets/icons/wifi.svg"
                symbolSize: 23
                symbolOffsetY: 1
                active: Papi.networkConnection.type === "ethernet" || (Papi.wifiAvailable && Papi.wifiEnabled)
                toggleable: Papi.wifiAvailable && (Papi.networkConnection.type === "wifi" || Papi.networkConnection.type === "none")
                externallyManaged: true
                subtitle: Papi.networkConnection.type === "ethernet" ? Papi.networkConnection.name : !Papi.wifiAvailable ? qsTranslate("Pedro", "bluetooth.status.unavailableShort") : Papi.wifiConnected ? Papi.connectedWifiName + " · Conectado" : Papi.wifiEnabled ? qsTranslate("Pedro", "network.wifi.status.disconnected") : qsTranslate("Pedro", "bluetooth.status.off")
                statusColor: Papi.wifiConnected ? Theme.statusConnected : active ? Theme.statusActive : Theme.statusInactive
                onToggleRequested: state => controller.setWifiEnabled(state)
                onActivated: controller.requestWifi()
            }
            Quick.Tile {
                id: bluetoothTile
                title: qsTranslate("Pedro", "bluetooth.title")
                subtitle: !Papi.bluetoothAvailable ? qsTranslate("Pedro", "bluetooth.status.unavailableShort") : active ? qsTranslate("Pedro", "shell.focus.enabled") : qsTranslate("Pedro", "bluetooth.status.off")
                icon: "../../../assets/icons/bluetooth.svg"
                active: Papi.bluetoothAvailable && Papi.bluetoothEnabled
                toggleable: Papi.bluetoothAvailable
                externallyManaged: true
                statusColor: active ? Theme.statusActive : Theme.statusInactive
                onToggleRequested: state => controller.setBluetoothEnabled(state)
                onActivated: controller.requestBluetooth()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.overlayPressed
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Slider.Tile {
                title: qsTranslate("Pedro", "shell.system.brightness")
                icon: "../../../assets/icons/brightness.svg"
                interactive: Papi.screenBrightness.available
                level: Papi.screenBrightness.value / 100
                onLevelMoved: value => Papi.screenBrightness.setValue(Math.round(value * 100))
            }
            Slider.Tile {
                title: qsTranslate("Pedro", "shell.sound.title")
                icon: Papi.audioVolume.muted ? "../../../assets/icons/muted.svg" : "../../../assets/icons/speaker.svg"
                iconInteractive: true
                onIconClicked: Papi.audioVolume.toggleMuted()
                interactive: Papi.audioVolume.available
                level: Papi.audioVolume.muted ? 0 : Papi.audioVolume.value / 100
                onLevelMoved: value => Papi.audioVolume.setValue(Math.round(value * 100))
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.overlayPressed
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 144

            GridLayout {
                anchors.fill: parent
                columns: 2
                columnSpacing: 10
                rowSpacing: 0

                Toggle.Tile {
                    Layout.preferredHeight: 48
                    title: qsTranslate("Pedro", "shell.focus.title")
                    navigable: false
                    subtitle: active ? qsTranslate("Pedro", "shell.focus.enabled") : qsTranslate("Pedro", "bluetooth.status.off")
                    icon: active ? "../../../assets/icons/crescent.svg" : "../../../assets/icons/moon.svg"
                    activeColor: Theme.focusActive
                    active: Papi.focusMode.active
                    toggleable: false
                    enabled: Papi.focusMode.available
                    onActivated: Papi.focusMode.toggle()
                }
                Toggle.Tile {
                    Layout.preferredHeight: 48
                    title: qsTranslate("Pedro", "shell.system.powerSaving.title")
                    navigable: false
                    subtitle: active ? qsTranslate("Pedro", "shell.focus.enabled") : qsTranslate("Pedro", "bluetooth.status.off")
                    icon: "../../../assets/icons/leaf.svg"
                    activeColor: Theme.batteryHealthy
                    active: Papi.powerSaving.active
                    toggleable: false
                    enabled: Papi.powerSaving.available && !Papi.powerSaving.busy
                    onActivated: Papi.powerSaving.toggle()
                }
                Toggle.Tile {
                    Layout.preferredHeight: 48
                    title: qsTranslate("Pedro", "shell.display.title")
                    subtitle: active ? qsTranslate("Pedro", "shell.display.connected") : qsTranslate("Pedro", "shell.display.disconnected")
                    icon: "../../../assets/icons/display.svg"
                    active: true
                    onActivated: controller.showNotice(qsTranslate("Pedro", "shell.display.pending"))
                }
                Toggle.Tile {
                    Layout.preferredHeight: 48
                    title: qsTranslate("Pedro", "shell.nightLight.title")
                    navigable: false
                    subtitle: active ? qsTranslate("Pedro", "shell.nightLight.automatic") : qsTranslate("Pedro", "bluetooth.status.off")
                    icon: "../../../assets/icons/brightness.svg"
                    active: Papi.nightLight.active
                    activeColor: Theme.nightLightActive
                    toggleable: false
                    enabled: Papi.nightLight.available
                    onActivated: Papi.nightLight.toggle()
                }
                Toggle.Tile {
                    Layout.preferredHeight: 48
                    title: qsTranslate("Pedro", "shell.keyboard.title")
                    subtitle: Papi.keyboard.layouts.length > 0 ? Papi.keyboard.layouts[0].name : qsTranslate("Pedro", "keyboard.empty")
                    icon: "../../../assets/icons/keyboard.svg"
                    active: true
                    toggleable: false
                    onActivated: root.keyboardRequested()
                }
                Toggle.Tile {
                    Layout.preferredHeight: 48
                    symbolColor: Theme.controlSymbol
                    title: qsTranslate("Pedro", "shell.capture.title")
                    navigable: false
                    toggleable: false
                    enabled: !Papi.capture.busy
                    subtitle: qsTranslate("Pedro", "shell.capture.subtitle")
                    icon: "../../../assets/icons/camera.svg"
                    onActivated: root.captureRequested()
                }
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 124
                color: Theme.overlayPressed
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.overlayPressed
        }

        Text {
            Layout.fillWidth: true
            visible: Papi.capture.error.length > 0
            text: Papi.capture.error
            color: Theme.textMuted
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }

        Media.Card {
            onPreviousRequested: controller.showNotice(qsTranslate("Pedro", "media.previous.pending"))
            onPlayRequested: controller.showNotice(qsTranslate("Pedro", "media.playback.pending"))
            onNextRequested: controller.showNotice(qsTranslate("Pedro", "media.next.pending"))
        }

    }
}
