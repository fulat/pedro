pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import "../icon" as Icon
import "../media" as Media
import "../logic/pixel.js" as Pixel
import "../logic/theme.js" as Theme

Item {
    id: root

    property bool expanded: false

    signal previousRequested()
    signal playRequested()
    signal nextRequested()

    implicitWidth: 350
    implicitHeight: 45
    clip: true

    RowLayout {
        id: compactLayout

        anchors.fill: parent
        anchors.leftMargin: 2
        anchors.rightMargin: 2
        anchors.topMargin: 1
        anchors.bottomMargin: 1
        spacing: 5
        opacity: root.expanded ? 0 : 1
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: root.expanded ? 240 : 180
                easing.type: Easing.InOutQuad
            }
        }

        Rectangle {
            Layout.preferredWidth: 25
            Layout.preferredHeight: 25
            radius: 7
            color: "#263447"
            clip: true

            Image {
                anchors.fill: parent
                source: "../../assets/artwork.svg"
                sourceSize: Qt.size(Pixel.physical(width, Screen.devicePixelRatio),
                                    Pixel.physical(height, Screen.devicePixelRatio))
                fillMode: Image.PreserveAspectCrop
                smooth: true
                mipmap: false
            }
        }

        ColumnLayout {
            Layout.preferredWidth: 80
            Layout.fillHeight: true
            spacing: 0

            Item { Layout.fillHeight: true }

            Controls.Label {
                Layout.fillWidth: true
                text: "Blinding Lights"
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSmall
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            Controls.Label {
                Layout.fillWidth: true
                text: "The Weeknd"
                color: "#a8b4c7"
                font.pixelSize: Theme.fontTiny
                elide: Text.ElideRight
            }

            Item { Layout.fillHeight: true }
        }

        // Media.Button {
        //     icon: "../../assets/icons/previous.svg"
        //     onActivated: root.previousRequested()
        // }
        //
        // Media.Button {
        //     icon: "../../assets/icons/pause.svg"
        //     emphasized: true
        //     onActivated: root.playRequested()
        // }
        //
        // Media.Button {
        //     icon: "../../assets/icons/next.svg"
        //     onActivated: root.nextRequested()
        // }

        Item { Layout.fillHeight: true }


        //
        // Icon.Tinted {
        //     Layout.leftMargin: 2
        //     Layout.preferredWidth: 14
        //     Layout.preferredHeight: 14
        //     source: "../../assets/icons/speaker.svg"
        //     tint: "#c5cfdd"
        // }

        Item {
            Layout.fillWidth: true
            Layout.minimumWidth: 40
            Layout.preferredHeight: 24

            Row {
                anchors.centerIn: parent
                spacing: 2

                Repeater {
                    model: [4,8, 8,8,8, 9,9,9, 13, 18, 17, 25, 15, 9, 17, 9,9,9,6,7,7,12, 7, 3]

                    delegate: Rectangle {
                        required property int modelData

                        width: 2
                        height: modelData
                        anchors.verticalCenter: parent.verticalCenter
                        radius: 1
                        color: "#8094b0"
                    }
                }
            }
        }
    }

    RowLayout {
        id: expandedLayout

        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        anchors.topMargin: 4
        anchors.bottomMargin: 4
        spacing: 10
        opacity: root.expanded ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: root.expanded ? 240 : 180
                easing.type: Easing.InOutQuad
            }
        }

        Rectangle {
            Layout.preferredWidth: 70
            Layout.preferredHeight: 70
            Layout.alignment: Qt.AlignVCenter
            radius: 14
            color: "#263447"
            clip: true

            Image {
                anchors.fill: parent
                source: "../../assets/artwork.svg"
                sourceSize: Qt.size(Pixel.physical(width, Screen.devicePixelRatio),
                                    Pixel.physical(height, Screen.devicePixelRatio))
                fillMode: Image.PreserveAspectCrop
                smooth: true
                mipmap: false
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 2

            Controls.Label {
                Layout.fillWidth: true
                text: "Blinding Lights"
                color: Theme.textPrimary
                font.pixelSize: Theme.fontNormal
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Controls.Label {
                Layout.fillWidth: true
                text: "The Weeknd"
                color: "#a8b4c7"
                font.pixelSize: Theme.fontSmall
                elide: Text.ElideRight
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Media.Button {
                    icon: "../../assets/icons/previous.svg"
                    onActivated: root.previousRequested()
                }

                Media.Button {
                    icon: "../../assets/icons/pause.svg"
                    emphasized: true
                    onActivated: root.playRequested()
                }

                Media.Button {
                    icon: "../../assets/icons/next.svg"
                    onActivated: root.nextRequested()
                }

                Item { Layout.fillWidth: true }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 14
                spacing: 6

                Icon.Tinted {
                    Layout.preferredWidth: 14
                    Layout.preferredHeight: 14
                    source: "../../assets/icons/speaker.svg"
                    tint: "#c5cfdd"
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 10

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 3
                        radius: 2
                        color: "#3d4e66"
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width * 0.62
                        height: 3
                        radius: 2
                        color: "#6aa5ff"
                    }

                    Rectangle {
                        x: parent.width * 0.62 - width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        width: 8
                        height: 8
                        radius: 4
                        color: "#f4f7fb"
                    }
                }
            }
        }
    }
}
