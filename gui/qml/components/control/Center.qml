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
                title: "Wi-Fi"
                icon: "../../../assets/icons/wifi.svg"
                symbolSize: 23
                symbolOffsetY: 1
                active: Papi.wifiEnabled
                toggleable: true
                externallyManaged: true
                subtitle: Papi.wifiConnected ? Papi.connectedWifiName + " · Conectado" : Papi.wifiEnabled ? "Sin conexión" : "Desactivado"
                statusColor: root.wifiConnected ? Theme.statusConnected : active ? Theme.statusActive : Theme.statusInactive
                onToggleRequested: state => controller.setWifiEnabled(state)
                onActivated: controller.requestWifi()
            }
            Quick.Tile {
                id: bluetoothTile
                title: "Bluetooth"
                subtitle: !Papi.bluetoothAvailable ? "No disponible" : active ? "Activado" : "Desactivado"
                icon: "../../../assets/icons/bluetooth.svg"
                active: Papi.bluetoothEnabled
                toggleable: true
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
                title: "Brillo"
                icon: "../../../assets/icons/brightness.svg"
                level: 0.58
            }
            Slider.Tile {
                title: "Sonido"
                icon: "../../../assets/icons/speaker.svg"
                level: 0.62
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
                    title: "Modo enfoque"
                    subtitle: active ? "Activado" : "Desactivado"
                    icon: "../../../assets/icons/moon.svg"
                    active: true
                    onActivated: controller.showNotice("El modo Enfoque es una vista previa")
                }
                Toggle.Tile {
                    title: "Ahorro de energía"
                    subtitle: active ? "Activado" : "Desactivado"
                    icon: "../../../assets/icons/leaf.svg"
                    activeColor: Theme.batteryHealthy
                    onActivated: controller.showNotice("Ahorro de energía se conectará a PAPI Power")
                }
                Toggle.Tile {
                    title: "Pantalla externa"
                    subtitle: active ? "Conectada" : "Desconectada"
                    icon: "../../../assets/icons/display.svg"
                    active: true
                    onActivated: controller.showNotice("La detección de pantallas todavía está pendiente")
                }
                Toggle.Tile {
                    title: "Luz nocturna"
                    subtitle: active ? "Automático" : "Desactivado"
                    icon: "../../../assets/icons/brightness.svg"
                    active: true
                    onActivated: controller.showNotice("La luz nocturna se conectará al módulo de pantalla")
                }
                Toggle.Tile {
                    title: "Teclado"
                    subtitle: "Español (ES)"
                    icon: "../../../assets/icons/keyboard.svg"
                    active: true
                    toggleable: false
                    onActivated: controller.showNotice("La selección de teclado todavía está pendiente")
                }
                Toggle.Tile {
                    symbolColor: Theme.controlSymbol
                    title: "Cámara"
                    subtitle: active ? "Activada" : "Desactivada"
                    icon: "../../../assets/icons/camera.svg"
                    onActivated: controller.showNotice("La cámara todavía no está conectada a PAPI")
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
            onPreviousRequested: controller.showNotice("Pista anterior · pendiente de conexión con Qt Multimedia")
            onPlayRequested: controller.showNotice("Reproducción · pendiente de conexión con Qt Multimedia")
            onNextRequested: controller.showNotice("Pista siguiente · pendiente de conexión con Qt Multimedia")
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
                title: "Ajustes"
                icon: "../../../assets/icons/settings.svg"
                separator: true
                onActivated: controller.requestSettings()
            }
            Action.Tile {
                title: "Bloquear"
                icon: "../../../assets/icons/lock.svg"
                separator: true
                onActivated: controller.showNotice("Bloquear se conectará a la sesión de Pedro")
            }
            Action.Tile {
                title: "Reiniciar"
                icon: "../../../assets/icons/restart.svg"
                separator: true
                onActivated: controller.showNotice("Reiniciar requiere PAPI Power")
            }
            Action.Tile {
                title: "Apagar"
                icon: "../../../assets/icons/power.svg"
                onActivated: controller.showNotice("Apagar requiere PAPI Power")
            }
        }
    }
}
