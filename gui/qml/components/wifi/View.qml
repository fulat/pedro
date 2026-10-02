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

    implicitHeight: 52 + 1 + 36 + (Papi.wifiAvailable && Papi.wifiEnabled && Papi.wifiNetworks.length > 0 ? Math.min(Papi.wifiNetworks.length, 4) * 54 : 180) + 1 + 40 + 20

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
            Layout.preferredHeight: 52
            spacing: 12

            Rectangle {
                implicitWidth: 34
                implicitHeight: 34
                radius: 17
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
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                }

                Controls.Label {
                    Layout.fillWidth: true
                    text: !Papi.wifiAvailable ? qsTranslate("Pedro", "network.wifi.empty.unavailableTitle") : Papi.wifiConnected ? Papi.connectedWifiName : Papi.wifiEnabled ? qsTranslate("Pedro", "network.wifi.status.disconnected") : qsTranslate("Pedro", "bluetooth.status.off")
                    color: Papi.wifiConnected ? Theme.statusWifiConnected : Theme.textMuted
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }

            Toggle.Switch {
                interactive: Papi.wifiAvailable
                active: Papi.wifiAvailable && Papi.wifiEnabled
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
            Layout.preferredHeight: 36
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

                enabled: Papi.wifiAvailable && Papi.wifiEnabled && !Papi.wifiScanning
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
                    Layout.preferredWidth: 60
                    Layout.preferredHeight: 52

                    Rectangle {
                        anchors.centerIn: parent
                        width: 56
                        height: 56
                        radius: width / 2
                        color: Theme.wifiGlowInner
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 44
                        height: 44
                        radius: width / 2
                        color: Theme.wifiGlowOuter
                    }

                    Icon.Tinted {
                        anchors.centerIn: parent
                        width: 44
                        height: 44
                        source: "../../../assets/icons/wifi-off.svg"
                        tint: Theme.white
                    }
                }

                Controls.Label {
                    Layout.fillWidth: true
                    text: !Papi.wifiAvailable ? qsTranslate("Pedro", "network.wifi.empty.unavailableTitle") : !Papi.wifiEnabled ? qsTranslate("Pedro", "network.wifi.empty.disabledTitle") : Papi.wifiError !== "" ? qsTranslate("Pedro", "network.wifi.empty.loadFailed") : qsTranslate("Pedro", "network.wifi.empty.noNetworks")
                    color: Theme.white
                    font.pixelSize: 14
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
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.buttonBorder
        }

        Loader {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            source: "../network/footer.qml"
            onLoaded: item.activated.connect(root.settingsRequested)
        }
    }
}
