pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "../icon" as Icon
import "../../scripts/theme.js" as Theme

Item {
    id: root

    signal settingsRequested
    signal diagnosticsRequested

    readonly property bool connected: Backend.networkConnection.type !== "none"

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 64

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 2
                anchors.rightMargin: 12
                spacing: 18

                Rectangle {
                    Layout.preferredWidth: 52
                    Layout.preferredHeight: 52
                    radius: 26
                    color: "#28ffffff"

                    Icon.Tinted {
                        anchors.centerIn: parent
                        width: 28
                        height: 28
                        source: "../../../assets/icons/share.svg"
                        tint: Theme.white
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Label {
                        text: Backend.networkConnection.type === "ethernet" ? qsTranslate("Pedro", "settings.network.ethernet") : qsTranslate("Pedro", "network.connection.title")
                        color: Theme.white
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                    }

                    RowLayout {
                        spacing: 6

                        Rectangle {
                            implicitWidth: 9
                            implicitHeight: 9
                            radius: 4.5
                            color: root.connected ? Theme.statusWifiConnected : Theme.textMuted
                        }

                        Label {
                            text: qsTranslate("Pedro", root.connected ? "settings.network.connected" : "settings.network.disconnected")
                            color: Theme.textMuted
                            font.pixelSize: 13
                        }
                    }
                }

                Icon.Tinted {
                    source: "../../../assets/icons/chevron.svg"
                    Layout.preferredWidth: 14
                    Layout.preferredHeight: 14
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.settingsRequested()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 168
            radius: 18
            color: "#14ffffff"
            border.color: "#20ffffff"
            antialiasing: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 0

                Detail {
                    title: qsTranslate("Pedro", "settings.network.connectionName")
                    value: Backend.networkConnection.name || "—"
                    icon: "../../../assets/icons/ethernet.svg"
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: "#18ffffff"
                }

                Detail {
                    title: qsTranslate("Pedro", "settings.network.ip")
                    value: "—"
                    icon: "../../../assets/icons/location.svg"
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: "#18ffffff"
                }

                Detail {
                    title: qsTranslate("Pedro", "settings.network.speed")
                    value: "—"
                    icon: "../../../assets/icons/speed.svg"
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Loader {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                source: "footer.qml"
                onLoaded: item.activated.connect(root.settingsRequested)
            }

            Loader {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                source: "footer.qml"
                onLoaded: {
                    item.title = Qt.binding(() => qsTranslate("Pedro", "settings.network.diagnostics"));
                    item.icon = Qt.resolvedUrl("../../../assets/icons/diagnostics.svg");
                    item.outlined = false;
                    item.activated.connect(root.diagnosticsRequested);
                }
            }
        }
    }

    component Detail: RowLayout {
        id: detail

        required property string title
        required property string value
        required property url icon

        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 18

        Icon.Tinted {
            source: detail.icon
            tint: Theme.white
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            Label {
                text: detail.title
                color: Theme.textMuted
                font.pixelSize: 11
            }

            Label {
                Layout.fillWidth: true
                text: detail.value
                color: Theme.white
                font.pixelSize: 13
                elide: Text.ElideRight
            }
        }
    }
}
