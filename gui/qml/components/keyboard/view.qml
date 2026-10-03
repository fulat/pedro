pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import gui
import "../icon" as Icon
import "../../scripts/theme.js" as Theme

Item {
    id: root
    property bool configuration: false
    implicitHeight: content.implicitHeight
    signal backRequested()
    signal settingsRequested()

    ColumnLayout {
        id: content
        anchors.fill: parent
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            spacing: 10

            Button {
                id: back
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                onClicked: root.backRequested()
                contentItem: Icon.Tinted {
                    source: "../../../assets/icons/chevron.svg"
                    rotation: 180
                    width: 12
                    height: 12
                }
                background: Rectangle {
                    radius: 15
                    color: back.down ? Theme.overlayPressed : back.hovered ? Theme.overlayHover : Theme.cardSurface
                }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
            }
            Icon.Tinted {
                source: "../../../assets/icons/keyboard.svg"
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
            }
            Label {
                Layout.fillWidth: true
                text: root.configuration ? qsTranslate("Pedro", "keyboard.settings") : qsTranslate("Pedro", "shell.keyboard.title")
                color: Theme.white
                font.pixelSize: 16
                font.weight: Font.DemiBold
                wrapMode: Text.WordWrap
            }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.overlayPressed
        }
        Repeater {
            model: root.configuration ? [] : Papi.keyboard.layouts.slice(0, 3)
            delegate: Label {
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(48, implicitHeight + 12)
                leftPadding: 12
                rightPadding: 12
                text: modelData.name
                color: Theme.white
                font.pixelSize: 13
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.WordWrap
            }
        }
        Label {
            Layout.fillWidth: true
            Layout.preferredHeight: root.configuration ? 120 : 48
            visible: root.configuration || Papi.keyboard.layouts.length === 0
            text: root.configuration ? qsTranslate("Pedro", "keyboard.configuration.pending") : qsTranslate("Pedro", "keyboard.empty")
            color: Theme.textMuted
            font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.WordWrap
        }
        Loader {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            visible: !root.configuration
            source: "../network/footer.qml"
            onLoaded: {
                item.title = Qt.binding(() => qsTranslate("Pedro", "keyboard.settings"));
                item.outlined = true;
                item.activated.connect(root.settingsRequested);
            }
        }
    }
}
