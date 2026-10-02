import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "../icon" as Icon
import "../../scripts/theme.js" as Theme

Item {
    id: root

    signal settingsRequested

    readonly property bool connected: Backend.networkConnection.type !== "none"

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: 20
                color: Theme.overlayHover

                Icon.Tinted {
                    anchors.centerIn: parent
                    width: 23
                    height: 23
                    source: "../../../assets/icons/ethernet.svg"
                    tint: Theme.white
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Label {
                    text: Backend.networkConnection.type === "ethernet" ? qsTranslate("Pedro", "settings.network.ethernet") : qsTranslate("Pedro", "network.connection.title")
                    color: Theme.white
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                }

                RowLayout {
                    spacing: 6

                    Rectangle {
                        width: 6
                        height: 6
                        radius: 3
                        color: root.connected ? "#79b994" : Theme.textMuted
                    }

                    Label {
                        text: qsTranslate("Pedro", root.connected ? "settings.network.connected" : "settings.network.disconnected")
                        color: Theme.textMuted
                        font.pixelSize: 11
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.buttonBorder
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 6

            Label {
                text: qsTranslate("Pedro", "settings.network.connectionName")
                color: Theme.textMuted
                font.pixelSize: 11
            }

            Label {
                Layout.fillWidth: true
                text: Backend.networkConnection.name || qsTranslate("Pedro", "network.connection.none")
                color: Theme.white
                font.pixelSize: 13
                font.weight: Font.Medium
                elide: Text.ElideRight
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.buttonBorder
        }

        Loader {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            source: "footer.qml"
            onLoaded: item.activated.connect(root.settingsRequested)
        }
    }
}
