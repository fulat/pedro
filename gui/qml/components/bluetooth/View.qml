pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import gui
import "../../controllers" as Controllers
import "../icon" as Icon
import "../option" as Option
import "../toggle" as Toggle
import "../../scripts/theme.js" as Theme

Item {
    id: root

    signal backRequested
    signal settingsRequested
    signal deviceRequested(string name)

    // Connects Bluetooth presentation events to the controller.
    Controllers.Bluetooth {
        id: controller
        view: root
    }

    onVisibleChanged: controller.visibilityChanged(visible)

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
                color: Theme.cardSurface
                border.width: 1
                border.color: Theme.buttonBorder

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: backMouse.pressed ? Theme.overlayPressed : backMouse.containsMouse ? Theme.overlayHover : "transparent"
                }

                Icon.Tinted {
                    anchors.centerIn: parent
                    width: 10
                    height: 16
                    rotation: 180
                    source: "../../../assets/icons/chevron.svg"
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
                    text: qsTranslate("Pedro", "bluetooth.title")
                    color: Theme.white
                    font.pixelSize: 20
                    font.weight: Font.DemiBold
                }

                Controls.Label {
                    Layout.fillWidth: true
                    text: !Papi.bluetoothAvailable ? qsTranslate("Pedro", "bluetooth.status.unavailableShort") : Papi.bluetoothEnabled ? qsTranslate("Pedro", "bluetooth.status.active") : qsTranslate("Pedro", "bluetooth.status.off")
                    color: Theme.textMuted
                    font.pixelSize: 9
                    elide: Text.ElideRight
                }
            }

            Toggle.Switch {
                interactive: Papi.bluetoothAvailable
                active: Papi.bluetoothAvailable && Papi.bluetoothEnabled
                onToggled: state => Papi.setBluetoothEnabled(state)
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.overlayPressed
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            visible: Papi.bluetoothEnabled
            spacing: 8

            Controls.Label {
                Layout.fillWidth: true
                text: qsTranslate("Pedro", "bluetooth.devices.title")
                color: Theme.white
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
                text: Papi.bluetoothScanning ? qsTranslate("Pedro", "common.searching") : Papi.bluetoothDevices.length > 0 ? qsTranslate("Pedro", "common.searchMore") : qsTranslate("Pedro", "common.search")
                onClicked: Papi.scanBluetooth()

                contentItem: Controls.Label {
                    text: scanButton.text
                    color: scanButton.enabled ? Theme.white : Theme.textMuted
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                background: Rectangle {
                    implicitWidth: Papi.bluetoothDevices.length > 0 ? 104 : 88
                    implicitHeight: 34
                    radius: 17
                    color: Theme.cardSurface
                    border.width: 1
                    border.color: Theme.buttonBorder

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: scanButton.down ? Theme.overlayPressed : scanButton.hovered ? Theme.overlayHover : "transparent"
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
                    color: Theme.overlaySubtle
                    border.width: 1
                    border.color: Theme.cardBorder

                    Icon.Tinted {
                        anchors.centerIn: parent
                        width: 54
                        height: 54
                        source: "../../../assets/icons/bluetooth.svg"
                        tint: Theme.white
                    }
                }

                Controls.Label {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    text: !Papi.bluetoothAvailable ? qsTranslate("Pedro", "bluetooth.status.unavailable") : !Papi.bluetoothEnabled ? qsTranslate("Pedro", "bluetooth.status.disabled") : Papi.bluetoothScanning ? qsTranslate("Pedro", "bluetooth.devices.searching") : qsTranslate("Pedro", "bluetooth.devices.empty")
                    color: Theme.white
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                }

                Controls.Label {
                    Layout.fillWidth: true
                    Layout.leftMargin: 12
                    Layout.rightMargin: 12
                    text: !Papi.bluetoothAvailable ? qsTranslate("Pedro", "bluetooth.empty.adapterMissing") : !Papi.bluetoothEnabled ? qsTranslate("Pedro", "bluetooth.empty.disabledHint") : Papi.bluetoothError !== "" ? Papi.bluetoothError : Papi.bluetoothScanning ? qsTranslate("Pedro", "bluetooth.empty.searchingHint") : qsTranslate("Pedro", "bluetooth.empty.noDevicesHint")
                    color: Theme.textMuted
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
            color: Theme.overlayPressed
        }

        Option.Row {
            Layout.preferredHeight: 62
            title: qsTranslate("Pedro", "bluetooth.settings.title")
            icon: "../../../assets/icons/settings.svg"
            onActivated: root.settingsRequested()
        }
    }
}
