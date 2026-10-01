pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "../icon" as Icon
import "palette.js" as Palette

Button {
    id: button
    property string symbol: ""
    property bool primary: false
    property bool arrow: false
    readonly property var colors: Palette.colors(Backend.appearanceMode)
    implicitHeight: 38
    implicitWidth: contentItem.implicitWidth + 24
    hoverEnabled: true
    leftPadding: 12
    rightPadding: 12
    HoverHandler { cursorShape: Qt.PointingHandCursor }
    contentItem: RowLayout {
        spacing: 8
        Icon.Tinted {
            visible: button.symbol.length > 0
            source: button.symbol.length ? button.symbol + ".svg" : ""
            tint: button.primary ? "white" : button.colors.accent
            Layout.preferredWidth: 16
            Layout.preferredHeight: 16
        }
        Text {
            visible: text.length > 0
            text: button.text
            color: button.primary ? "white" : button.colors.ink
            font.pixelSize: 12
        }
        Text { visible: button.arrow; text: "⌄"; color: button.primary ? "white" : button.colors.ink; font.pixelSize: 15 }
    }
    background: Rectangle {
        radius: 10
        color: button.primary ? button.colors.accent : button.hovered ? button.colors.selected : button.flat ? "transparent" : button.colors.card
        border.color: button.primary ? button.colors.accent : button.flat ? "transparent" : button.colors.line
        Behavior on color { ColorAnimation { duration: 150 } }
    }
}
