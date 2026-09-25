pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import gui
import "../icon" as Icon
import "../option" as Option
import "../toggle" as Toggle
import "../logic/theme.js" as Theme

Item {
    id: root

    signal backRequested()
    signal settingsRequested()
    signal deviceRequested(string name)

    onVisibleChanged: {
        if (!visible)
            return

        Papi.refreshBluetooth()

        if (Papi.bluetoothAvailable && Papi.bluetoothEnabled)
            Papi.scanBluetooth()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 64
            spacing: 12

            Rectangle {
                implicitWidth: 42
                implicitHeight: 42
                radius: 21
                color: "#4d1a2a40"
                border.width: 1
                border.color: "#385f7692"

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: backMouse.pressed ? Theme.controlPressed
                                             : backMouse.containsMouse ? Theme.controlHover : "transparent"
                }

                Icon.Tinted {
                    anchors.centerIn: parent
                    width: 10
                    height: 16
                    rotation: 180
                    source: "../../assets/icons/chevron.svg"
                }

                MouseArea {
                    id: backMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.backRequested()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Controls.Label {
                    Layout.fillWidth: true
                    text: "Bluetooth"
                    color: Theme.textPrimary
                    font.pixelSize: 20
                    font.weight: Font.DemiBold
                }

                Controls.Label {
                    Layout.fillWidth: true
                    text: !Papi.bluetoothAvailable
                          ? "No disponible"
                          : Papi.bluetoothEnabled
                            ? "Activado · visible para dispositivos"
                            : "Desactivado"
                    color: Theme.textSecondary
                    font.pixelSize: 9
                    elide: Text.ElideRight
                }
            }

            Toggle.Switch {
                active: Papi.bluetoothEnabled
                onToggled: state => Papi.setBluetoothEnabled(state)
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.controlBorder
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            visible: Papi.bluetoothEnabled
            spacing: 8

            Controls.Label {
                Layout.fillWidth: true
                text: "Dispositivos"
                color: Theme.textPrimary
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }

            Controls.BusyIndicator {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                running: Papi.bluetoothScanning
                visible: running
            }

            Controls.Button {
                id: scanButton

                enabled: Papi.bluetoothAvailable && !Papi.bluetoothScanning
                text: Papi.bluetoothScanning
                      ? "Buscando…"
                      : Papi.bluetoothDevices.length > 0 ? "Buscar más" : "Buscar"
                onClicked: Papi.scanBluetooth()

                contentItem: Controls.Label {
                    text: scanButton.text
                    color: scanButton.enabled ? Theme.textPrimary : Theme.textSecondary
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                background: Rectangle {
                    implicitWidth: Papi.bluetoothDevices.length > 0 ? 104 : 88
                    implicitHeight: 34
                    radius: 17
                    color: "#4a18263a"
                    border.width: 1
                    border.color: "#526b87a8"

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: scanButton.down ? Theme.controlPressed
                                               : scanButton.hovered ? Theme.controlHover : "transparent"
                    }
                }

                HoverHandler {
                    cursorShape: scanButton.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ListView {
                id: deviceList

                anchors.fill: parent
                visible: Papi.bluetoothEnabled && count > 0
                model: Papi.bluetoothDevices
                spacing: 0
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                delegate: Device {
                    required property var modelData

                    width: deviceList.width
                    name: modelData.name
                    iconName: modelData.icon
                    connected: modelData.connected
                    paired: modelData.paired
                    onActivated: root.deviceRequested(name)
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width
                visible: deviceList.count === 0
                spacing: 10

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 106
                    Layout.preferredHeight: 106
                    radius: width / 2
                    color: "#101c2d46"
                    border.width: 1
                    border.color: "#41617fa8"

                    Icon.Tinted {
                        anchors.centerIn: parent
                        width: 54
                        height: 54
                        source: "../../assets/icons/bluetooth.svg"
                        tint: "#a8c5f0"
                    }
                }

                Controls.Label {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    text: !Papi.bluetoothAvailable
                          ? "Bluetooth no disponible"
                          : !Papi.bluetoothEnabled
                            ? "Bluetooth desactivado"
                            : Papi.bluetoothScanning
                              ? "Buscando dispositivos…"
                              : "No se encontraron dispositivos"
                    color: Theme.textPrimary
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                }

                Controls.Label {
                    Layout.fillWidth: true
                    Layout.leftMargin: 12
                    Layout.rightMargin: 12
                    text: !Papi.bluetoothAvailable
                          ? "BlueZ no detectó un adaptador Bluetooth."
                          : !Papi.bluetoothEnabled
                            ? "Actívalo para buscar y conectar\ndispositivos cercanos."
                            : Papi.bluetoothError !== ""
                              ? Papi.bluetoothError
                              : Papi.bluetoothScanning
                                ? "Mantén los dispositivos cercanos encendidos\ny en modo visible."
                                : "Asegúrate de que los dispositivos cercanos\nestén encendidos y en modo visible."
                    color: Theme.textSecondary
                    font.pixelSize: 11
                    lineHeight: 1.25
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.controlBorder
        }

        Option.Row {
            Layout.preferredHeight: 62
            title: "Configuración de Bluetooth"
            icon: "../../assets/icons/settings.svg"
            onActivated: root.settingsRequested()
        }
    }
}
