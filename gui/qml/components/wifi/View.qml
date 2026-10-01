pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import gui
import "../../controllers" as Controllers
import "../icon" as Icon
import "../toggle" as Toggle
import "../../scripts/theme.js" as Theme

Item {
    id: root

    signal backRequested
    signal settingsRequested

    // Connects Wi-Fi presentation events to the controller.
    Controllers.Wifi {
        id: controller
    }

    onVisibleChanged: controller.visibilityChanged(visible)

    ColumnLayout {
        anchors.fill: parent
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 58
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
                    text: qsTranslate("Pedro", "network.wifi.title")
                    color: Theme.white
                    font.pixelSize: 20
                    font.weight: Font.DemiBold
                }

                Controls.Label {
                    Layout.fillWidth: true
                    text: Papi.wifiConnected ? Papi.connectedWifiName + " · Conectado" : Papi.wifiEnabled ? qsTranslate("Pedro", "network.wifi.status.disconnected") : qsTranslate("Pedro", "bluetooth.status.off")
                    color: Papi.wifiConnected ? Theme.statusWifiConnected : Theme.textMuted
                    font.pixelSize: 9
                    elide: Text.ElideRight
                }
            }

            Toggle.Switch {
                active: Papi.wifiEnabled
                onToggled: state => Papi.setWifiEnabled(state)
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.overlayPressed
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            spacing: 8

            Controls.Label {
                Layout.fillWidth: true
                text: qsTranslate("Pedro", "network.wifi.networks.title")
                color: Theme.white
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }

            Controls.BusyIndicator {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                running: Papi.wifiScanning
                visible: running
            }

            Controls.Button {
                id: scanButton

                enabled: !Papi.wifiScanning
                text: Papi.wifiScanning ? qsTranslate("Pedro", "common.searching") : qsTranslate("Pedro", "common.search")
                onClicked: controller.scanRequested()

                contentItem: Controls.Label {
                    text: scanButton.text
                    color: scanButton.enabled ? Theme.white : Theme.textMuted
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                background: Rectangle {
                    implicitWidth: 88
                    implicitHeight: 32
                    radius: 16
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
                id: networkList

                anchors.fill: parent
                visible: count > 0 && Papi.wifiAvailable && Papi.wifiEnabled
                model: Papi.wifiNetworks
                spacing: 2
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                delegate: Network {
                    required property var modelData

                    width: networkList.width
                    name: modelData.name
                    strength: modelData.strength
                    secured: modelData.secured
                    connected: modelData.connected
                }
            }

            ColumnLayout {
                id: emptyState

                anchors.centerIn: parent
                width: parent.width
                visible: networkList.count === 0 && !Papi.wifiScanning
                spacing: 8

                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 112
                    Layout.preferredHeight: 98

                    Rectangle {
                        anchors.centerIn: parent
                        width: 104
                        height: 104
                        radius: width / 2
                        color: Theme.wifiGlowInner
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 78
                        height: 78
                        radius: width / 2
                        color: Theme.wifiGlowOuter
                    }

                    Icon.Tinted {
                        anchors.centerIn: parent
                        width: 78
                        height: 78
                        source: "../../../assets/icons/wifi-off.svg"
                        tint: Theme.white
                    }
                }

                Controls.Label {
                    Layout.fillWidth: true
                    text: !Papi.wifiAvailable ? qsTranslate("Pedro", "network.wifi.empty.unavailableTitle") : !Papi.wifiEnabled ? qsTranslate("Pedro", "network.wifi.empty.disabledTitle") : Papi.wifiError !== "" ? qsTranslate("Pedro", "network.wifi.empty.loadFailed") : qsTranslate("Pedro", "network.wifi.empty.noNetworks")
                    color: Theme.white
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                }

                Controls.Label {
                    Layout.fillWidth: true
                    text: !Papi.wifiAvailable ? qsTranslate("Pedro", "network.wifi.empty.adapterMissing") : !Papi.wifiEnabled ? qsTranslate("Pedro", "network.wifi.empty.enableHint") : Papi.wifiError !== "" ? Papi.wifiError : qsTranslate("Pedro", "network.wifi.empty.noNetworksHint")
                    color: Theme.white
                    font.pixelSize: 10
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                }

                Controls.Label {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    text: !Papi.wifiAvailable ? qsTranslate("Pedro", "network.wifi.empty.adapterHint") : !Papi.wifiEnabled ? qsTranslate("Pedro", "network.wifi.empty.disabledHint") : qsTranslate("Pedro", "network.wifi.empty.outOfRangeHint")
                    color: Theme.textMuted
                    font.pixelSize: 10
                    lineHeight: 1.25
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                }

                Rectangle {
                    id: settingsButton

                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 8
                    Layout.preferredWidth: 218
                    Layout.preferredHeight: 40
                    radius: height / 2
                    color: Theme.cardSurface
                    border.width: 1
                    border.color: Theme.buttonBorder

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: settingsMouse.pressed ? Theme.overlayPressed : settingsMouse.containsMouse ? Theme.overlayHover : "transparent"
                    }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 9

                        Icon.Tinted {
                            source: "../../../assets/icons/settings.svg"
                            Layout.preferredWidth: 18
                            Layout.preferredHeight: 18
                            tint: Theme.white
                        }

                        Controls.Label {
                            text: qsTranslate("Pedro", "network.settings.title")
                            color: Theme.white
                            font.pixelSize: 11
                            font.weight: Font.Medium
                        }

                        Controls.Label {
                            text: "↗"
                            color: Theme.white
                            font.pixelSize: 17
                            font.weight: Font.Medium
                        }
                    }

                    MouseArea {
                        id: settingsMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.settingsRequested()
                    }
                }
            }

            Controls.BusyIndicator {
                anchors.centerIn: parent
                width: 34
                height: 34
                running: Papi.wifiScanning
                visible: running
            }

            Controls.Label {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 8
                visible: Papi.wifiScanning
                text: qsTranslate("Pedro", "network.wifi.networks.searching")
                color: Theme.textMuted
                font.pixelSize: 10
            }
        }
    }
}
