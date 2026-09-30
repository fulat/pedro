pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic as Controls
import "../../scripts/theme.js" as Theme

Controls.Button {
    id: root
    property bool strongText: false
    leftPadding: 10
    rightPadding: 10
    topPadding: 7
    bottomPadding: 7

    contentItem: Controls.Label {
        text: root.text
        color: Theme.textPrimary
        font.pixelSize: Theme.fontNormal
        font.weight: root.strongText ? Font.Bold : Font.Medium
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    background: Rectangle {
        radius: 5
        color: root.down ? Theme.controlPressed
                         : (root.highlighted || root.hovered) ? Theme.controlHover : "transparent"
    }

    HoverHandler { cursorShape: Qt.PointingHandCursor }
}
