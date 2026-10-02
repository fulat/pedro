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
        spacing: 0

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 64

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 2
                anchors.rightMargin: 12
                spacing: 18

                Rectangle {
                    Layout.minimumWidth: 52
                    Layout.maximumWidth: 52
                    Layout.preferredWidth: 52
                    Layout.preferredHeight: 52
                    radius: 26
                    gradient: Gradient {
                        GradientStop { position: 0; color: "#80686485" }
                        GradientStop { position: 1; color: "#80534f70" }
                    }
                    border.color: "#28ffffff"

                    Icon.Tinted {
                        anchors.centerIn: parent
                        width: 28
                        height: 28
                        source: "../../../assets/icons/ethernet.svg"
                        tint: Theme.white
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Label {
                        Layout.fillWidth: true
                        text: Backend.networkConnection.type === "ethernet" ? qsTranslate("Pedro", "settings.network.ethernet") : qsTranslate("Pedro", "network.connection.title")
                        color: Theme.white
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignLeft
                        spacing: 6

                        Rectangle {
                            implicitWidth: 9
                            implicitHeight: 9
                            radius: 4.5
                            color: root.connected ? "#20dda1" : Theme.textMuted
                        }

                        Label {
                            text: qsTranslate("Pedro", root.connected ? "settings.network.connected" : "settings.network.disconnected")
                            color: Theme.textMuted
                            font.pixelSize: 13
                        }
                    }
                }

                Rectangle {
                    Layout.minimumWidth: 36
                    Layout.maximumWidth: 36
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    radius: 18
                    color: "#10ffffff"

                    Icon.Tinted {
                        anchors.centerIn: parent
                        source: "../../../assets/icons/chevron.svg"
                        width: 16
                        height: 16
                    }
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
            Layout.topMargin: 10
            Layout.bottomMargin: 10
            implicitHeight: 1
            color: "#18ffffff"
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 180
            radius: 18
            color: "#0fffffff"
            border.color: "#24ffffff"
            antialiasing: true

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 16
                anchors.topMargin: 8
                anchors.bottomMargin: 8
                spacing: 0

                Detail {
                    title: qsTranslate("Pedro", "settings.network.connectionName")
                    value: Backend.networkConnection.name || "—"
                    icon: "../../../assets/icons/link.svg"
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: "#18ffffff"
                }

                Detail {
                    title: qsTranslate("Pedro", "network.popup.localIp")
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
            Layout.topMargin: 14
            spacing: 8

            Loader {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                source: "footer.qml"
                onLoaded: {
                    item.title = Qt.binding(() => qsTranslate("Pedro", "network.popup.settings"));
                    item.outlined = true;
                    item.activated.connect(root.settingsRequested);
                }
            }

            Loader {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                source: "footer.qml"
                onLoaded: {
                    item.title = Qt.binding(() => qsTranslate("Pedro", "network.popup.diagnose"));
                    item.icon = Qt.resolvedUrl("../../../assets/icons/diagnostics.svg");
                    item.outlined = true;
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
        spacing: 28

        Icon.Tinted {
            source: detail.icon
            tint: Theme.white
            Layout.preferredWidth: 22
            Layout.preferredHeight: 22
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            Label {
                text: detail.title
                color: Theme.textMuted
                font.pixelSize: 12
            }

            Label {
                Layout.fillWidth: true
                text: detail.value
                color: Theme.white
                font.pixelSize: 14
                elide: Text.ElideRight
            }
        }
    }
}
