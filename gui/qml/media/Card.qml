pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import "../logic/pixel.js" as Pixel
import "../logic/theme.js" as Theme

Item {
    id: root
    signal previousRequested()
    signal playRequested()
    signal nextRequested()
    Layout.fillWidth: true
    Layout.preferredHeight: 94

    ColumnLayout {
        anchors.fill: parent
        spacing: 5
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Rectangle {
                implicitWidth: 48
                implicitHeight: 48
                radius: 8
                color: "#2a3748"
                clip: true
                Image {
                    anchors.fill: parent
                    source: "../../assets/artwork.svg"
                    fillMode: Image.PreserveAspectFit
                    sourceSize: Qt.size(Pixel.physical(width, Screen.devicePixelRatio),
                                        Pixel.physical(height, Screen.devicePixelRatio))
                    smooth: true
                    mipmap: false
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 105
                spacing: 2
                Controls.Label {
                    text: "Blinding Lights"
                    color: Theme.textPrimary
                    font.pixelSize: 11
                    font.weight: Font.Medium
                }
                Controls.Label {
                    text: "The Weeknd"
                    color: Theme.textSecondary
                    font.pixelSize: 9
                }
            }
            Button { icon: "../../assets/icons/previous.svg"; onActivated: root.previousRequested() }
            Button { icon: "../../assets/icons/pause.svg"; emphasized: true; onActivated: root.playRequested() }
            Button { icon: "../../assets/icons/next.svg"; onActivated: root.nextRequested() }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 4
            radius: 2
            color: "#40506a"
            Rectangle {
                width: parent.width * 0.36
                height: parent.height
                radius: 2
                color: "#5a9cff"
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Controls.Label { text: "1:12"; color: Theme.textSecondary; font.pixelSize: 8 }
            Item { Layout.fillWidth: true }
            Controls.Label { text: "3:20"; color: Theme.textSecondary; font.pixelSize: 8 }
        }
    }
}
