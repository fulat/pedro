import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "../icon" as Icon
import "../../scripts/theme.js" as Theme

Rectangle {
    id: root

    property string title: qsTranslate("Pedro", "settings.network.openSettings")
    property url icon: "../../../assets/icons/settings.svg"
    property bool outlined: true

    signal activated

    implicitHeight: 44
    radius: 18
    border.color: outlined ? "#18ffffff" : "transparent"
    color: mouse.pressed ? Theme.overlayPressed : mouse.containsMouse ? Theme.overlayHover : outlined ? "#06ffffff" : "transparent"

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 18

        Icon.Tinted {
            source: root.icon
            tint: Theme.white
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
        }

        Label {
            text: root.title
            color: Theme.white
            font.pixelSize: 13
            Layout.fillWidth: true
        }

        Label {
            text: "›"
            color: Theme.textMuted
            font.pixelSize: 22
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
