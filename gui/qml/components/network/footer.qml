import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "../icon" as Icon
import "../../scripts/theme.js" as Theme

Rectangle {
    id: root

    signal activated

    implicitHeight: 44
    radius: 9
    color: mouse.pressed ? Theme.overlayPressed : mouse.containsMouse ? Theme.overlayHover : "transparent"

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 10

        Icon.Tinted {
            source: "../../../assets/icons/settings.svg"
            tint: Theme.white
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
        }

        Label {
            text: qsTranslate("Pedro", "settings.network.openSettings")
            color: Theme.white
            font.pixelSize: 12
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
