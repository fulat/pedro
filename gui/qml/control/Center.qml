import QtQuick
import QtQuick.Layouts
import gui
import "../action" as Action
import "../media" as Media
import "../quick" as Quick
import "../slider" as Slider
import "../toggle" as Toggle
import "../logic/theme.js" as Theme

Item {
    id: root
    property string notice: Papi.wifiError !== "" ? Papi.wifiError : "Wi-Fi conectado mediante PAPI Network"
    readonly property bool wifiEnabled: Papi.wifiEnabled
    property alias bluetoothEnabled: bluetoothTile.active
    readonly property bool wifiConnected: Papi.wifiConnected
    signal settingsRequested()
    signal wifiRequested()
    signal bluetoothRequested()

    ColumnLayout {
        anchors.fill: parent
        spacing: 4

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Quick.Tile {
                id: wifiTile
                title: "Wi-Fi"
                icon: "../../assets/icons/wifi.svg"
                symbolSize: 22
                symbolOffsetY: 1
                active: Papi.wifiEnabled
                toggleable: true
                externallyManaged: true
                subtitle: Papi.wifiConnected
                          ? Papi.connectedWifiName + " · Conectado"
                          : Papi.wifiEnabled ? "Sin conexión" : "Desactivado"
                statusColor: root.wifiConnected ? "#41df91" : active ? "#579cff" : "#8290a4"
                onToggleRequested: state => Papi.setWifiEnabled(state)
                onDetailsRequested: root.wifiRequested()
            }
            Quick.Tile {
                id: bluetoothTile
                title: "Bluetooth"
                subtitle: active ? "Activado" : "Desactivado"
                icon: "../../assets/icons/bluetooth.svg"
                active: true
                statusColor: active ? "#579cff" : "#8290a4"
                onActivated: root.notice = active
                             ? "Bluetooth activado · pendiente de conexión con PAPI"
                             : "Bluetooth desactivado"
                onDetailsRequested: root.bluetoothRequested()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.controlBorder
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Slider.Tile { title: "Brillo"; icon: "../../assets/icons/brightness.svg"; level: 0.58 }
            Slider.Tile { title: "Sonido"; icon: "../../assets/icons/speaker.svg"; level: 0.62 }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.controlBorder
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
                    title: "Modo enfoque"
                    subtitle: active ? "Activado" : "Desactivado"
                    icon: "../../assets/icons/moon.svg"
                    active: true
                    onActivated: root.notice = "El modo Enfoque es una vista previa"
                }
                Toggle.Tile {
                    title: "Ahorro de energía"
                    subtitle: active ? "Activado" : "Desactivado"
                    icon: "../../assets/icons/leaf.svg"
                    activeColor: "#24d687"
                    onActivated: root.notice = "Ahorro de energía se conectará a PAPI Power"
                }
                Toggle.Tile {
                    title: "Pantalla externa"
                    subtitle: active ? "Conectada" : "Desconectada"
                    icon: "../../assets/icons/display.svg"
                    active: true
                    onActivated: root.notice = "La detección de pantallas todavía está pendiente"
                }
                Toggle.Tile {
                    title: "Night Light"
                    subtitle: active ? "Automático" : "Desactivado"
                    icon: "../../assets/icons/brightness.svg"
                    active: true
                    onActivated: root.notice = "Night Light se conectará al módulo de pantalla"
                }
                Toggle.Tile {
                    title: "Teclado"
                    subtitle: "Español (ES)"
                    icon: "../../assets/icons/keyboard.svg"
                    active: true
                    toggleable: false
                    onActivated: root.notice = "La selección de teclado todavía está pendiente"
                }
                Toggle.Tile {
                    symbolColor: "#f4f7ff"
                    title: "Cámara"
                    subtitle: active ? "Activada" : "Desactivada"
                    icon: "../../assets/icons/camera.svg"
                    onActivated: root.notice = "La cámara todavía no está conectada a PAPI"
                }
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 126
                color: Theme.controlBorder
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.controlBorder
        }

        Media.Card {
            onPreviousRequested: root.notice = "Pista anterior · pendiente de conexión con Qt Multimedia"
            onPlayRequested: root.notice = "Reproducción · pendiente de conexión con Qt Multimedia"
            onNextRequested: root.notice = "Pista siguiente · pendiente de conexión con Qt Multimedia"
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.controlBorder
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 4
            columnSpacing: 0
            rowSpacing: 0
            Action.Tile {
                title: "Ajustes"
                icon: "../../assets/icons/settings.svg"
                separator: true
                onActivated: root.settingsRequested()
            }
            Action.Tile {
                title: "Bloquear"
                icon: "../../assets/icons/lock.svg"
                separator: true
                onActivated: root.notice = "Bloquear se conectará a la sesión de Pedro"
            }
            Action.Tile {
                title: "Reiniciar"
                icon: "../../assets/icons/restart.svg"
                separator: true
                onActivated: root.notice = "Reiniciar requiere PAPI Power"
            }
            Action.Tile {
                title: "Apagar"
                icon: "../../assets/icons/power.svg"
                onActivated: root.notice = "Apagar requiere PAPI Power"
            }
        }
    }
}
