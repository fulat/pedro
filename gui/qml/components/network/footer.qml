import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "../icon" as Icon
import "../../scripts/theme.js" as Theme

Rectangle {
    id: root

    property string title: qsTranslate("Pedro", "settings.network.openSettings")
    property url icon: "../../../assets/icons/settings.svg"
    property bool outlined: false

    signal activated

    implicitHeight: 44
    radius: 20
    border.color: outlined ? "#24ffffff" : "transparent"
    color: mouse.pressed ? Theme.overlayPressed : mouse.containsMouse ? Theme.overlayHover : outlined ? "#0cffffff" : "transparent"

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: root.outlined ? 20 : 16
        anchors.rightMargin: 16
        spacing: root.outlined ? 28 : 18

        Icon.Tinted {
            source: root.icon
            tint: Theme.white
            Layout.preferredWidth: 22
            Layout.preferredHeight: 22
        }

        Label {
            text: root.title
            color: Theme.white
            font.pixelSize: 13
            Layout.fillWidth: true
        }

        Icon.Tinted {
            source: "../../../assets/icons/chevron.svg"
            tint: Theme.textMuted
            Layout.preferredWidth: 16
            Layout.preferredHeight: 16
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
