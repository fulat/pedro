import QtQuick
import QtQuick.Layouts
import gui
import "../../controllers" as Controllers
import "../action" as Action
import "../media" as Media
import "../quick" as Quick
import "../slider" as Slider
import "../toggle" as Toggle
import "../../scripts/theme.js" as Theme

Item {
    id: root
    implicitHeight: 568
    property alias notice: controller.notice
    readonly property bool wifiEnabled: Papi.wifiEnabled
    readonly property bool wifiConnected: Papi.wifiConnected
    signal settingsRequested
    signal wifiRequested
    signal bluetoothRequested

    // Connects control-center actions to backend and navigation behavior.
    Controllers.Control {
        id: controller
        view: root
    }

    ColumnLayout {
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
            Layout.preferredHeight: 162

            GridLayout {
                anchors.fill: parent
                columns: 2
                columnSpacing: 10
                rowSpacing: 0

                Toggle.Tile {
                    title: qsTranslate("Pedro", "shell.focus.title")
                    subtitle: active ? qsTranslate("Pedro", "shell.focus.enabled") : qsTranslate("Pedro", "bluetooth.status.off")
                    icon: "../../../assets/icons/moon.svg"
                    active: true
                    onActivated: controller.showNotice(qsTranslate("Pedro", "shell.focus.preview"))
                }
                Toggle.Tile {
                    title: qsTranslate("Pedro", "shell.system.powerSaving.title")
                    subtitle: active ? qsTranslate("Pedro", "shell.focus.enabled") : qsTranslate("Pedro", "bluetooth.status.off")
                    icon: "../../../assets/icons/leaf.svg"
                    activeColor: Theme.batteryHealthy
                    onActivated: controller.showNotice(qsTranslate("Pedro", "shell.system.powerSaving.pending"))
                }
                Toggle.Tile {
                    title: qsTranslate("Pedro", "shell.display.title")
                    subtitle: active ? qsTranslate("Pedro", "shell.display.connected") : qsTranslate("Pedro", "shell.display.disconnected")
                    icon: "../../../assets/icons/display.svg"
                    active: true
                    onActivated: controller.showNotice(qsTranslate("Pedro", "shell.display.pending"))
                }
                Toggle.Tile {
                    title: qsTranslate("Pedro", "shell.nightLight.title")
                    subtitle: active ? qsTranslate("Pedro", "shell.nightLight.automatic") : qsTranslate("Pedro", "bluetooth.status.off")
                    icon: "../../../assets/icons/brightness.svg"
                    active: true
                    onActivated: controller.showNotice(qsTranslate("Pedro", "shell.nightLight.pending"))
                }
                Toggle.Tile {
                    title: qsTranslate("Pedro", "shell.keyboard.title")
                    subtitle: qsTranslate("Pedro", "shell.keyboard.layout")
                    icon: "../../../assets/icons/keyboard.svg"
                    active: true
                    toggleable: false
                    onActivated: controller.showNotice(qsTranslate("Pedro", "shell.keyboard.pending"))
                }
                Toggle.Tile {
                    symbolColor: Theme.controlSymbol
                    title: qsTranslate("Pedro", "shell.camera.title")
                    subtitle: active ? qsTranslate("Pedro", "shell.camera.enabled") : qsTranslate("Pedro", "shell.camera.disabled")
                    icon: "../../../assets/icons/camera.svg"
                    onActivated: controller.showNotice(qsTranslate("Pedro", "shell.camera.pending"))
                }
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 142
                color: Theme.overlayPressed
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.overlayPressed
        }

        Media.Card {
            onPreviousRequested: controller.showNotice(qsTranslate("Pedro", "media.previous.pending"))
            onPlayRequested: controller.showNotice(qsTranslate("Pedro", "media.playback.pending"))
            onNextRequested: controller.showNotice(qsTranslate("Pedro", "media.next.pending"))
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.overlayPressed
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 4
            columnSpacing: 0
            rowSpacing: 0
            Action.Tile {
                title: qsTranslate("Pedro", "settings.title")
                icon: "../../../assets/icons/settings.svg"
                separator: true
                onActivated: controller.requestSettings()
            }
            Action.Tile {
                title: qsTranslate("Pedro", "shell.power.lock")
                icon: "../../../assets/icons/lock.svg"
                separator: true
                onActivated: controller.showNotice(qsTranslate("Pedro", "shell.power.lockPending"))
            }
            Action.Tile {
                title: qsTranslate("Pedro", "shell.power.restart")
                icon: "../../../assets/icons/restart.svg"
                separator: true
                onActivated: controller.showNotice(qsTranslate("Pedro", "shell.power.restartPending"))
            }
            Action.Tile {
                title: qsTranslate("Pedro", "shell.power.off")
                icon: "../../../assets/icons/power.svg"
                onActivated: controller.showNotice(qsTranslate("Pedro", "shell.power.offPending"))
            }
        }
    }
}
