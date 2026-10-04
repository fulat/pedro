pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import "../../scripts/pixel.js" as Pixel
import "../../scripts/theme.js" as Theme

Item {
    id: root
    signal previousRequested()
    signal playRequested()
    signal nextRequested()
    Layout.fillWidth: true
    Layout.preferredHeight: 88

    ColumnLayout {
        anchors.fill: parent
        spacing: 5
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Rectangle {
                implicitWidth: 44
                implicitHeight: 44
                radius: 8
                color: Theme.mediaArtworkBackground
                clip: true
                Image {
                    anchors.fill: parent
                    source: "image://icons/original/music.svg"
                    fillMode: Image.PreserveAspectFit
                    sourceSize: Qt.size(Pixel.physical(width, Screen.devicePixelRatio),
                                        Pixel.physical(height, Screen.devicePixelRatio))
                    smooth: true
                    mipmap: false
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 2
                Controls.Label {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: "Blinding Lights"
                    color: Theme.white
                    font.pixelSize: 15
                    font.weight: Font.Medium
                }
                Controls.Label {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: "The Weeknd"
                    color: Theme.textMuted
                    font.pixelSize: 13
                }
            }
            Button { icon: "../../../assets/icons/previous.svg"; onActivated: root.previousRequested() }
            Button { icon: "../../../assets/icons/pause.svg"; emphasized: true; onActivated: root.playRequested() }
            Button { icon: "../../../assets/icons/next.svg"; onActivated: root.nextRequested() }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 4
            radius: 2
            color: Theme.sliderTrack
            Rectangle {
                width: parent.width * 0.36
                height: parent.height
                radius: 2
                color: Theme.sliderFill
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Controls.Label { text: "1:12"; color: Theme.textMuted; font.pixelSize: 11 }
            Item { Layout.fillWidth: true }
            Controls.Label { text: "3:20"; color: Theme.textMuted; font.pixelSize: 11 }
        }
    }
}
