pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "../icon" as Icon
import "palette.js" as Palette

Item {
    id: header
    property var controller
    readonly property var colors: Palette.colors(Backend.appearanceMode)
    RowLayout {
        anchors.fill: parent
        anchors.rightMargin: 24
        spacing: 12
        Row {
            Loader { source: "button.qml"; onLoaded: { item.symbol = "back"; item.width = 39; item.enabled = Qt.binding(() => header.controller && header.controller.directory.canGoBack); item.clicked.connect(() => header.controller.back()); } }
            Loader { source: "button.qml"; onLoaded: { item.symbol = "forward"; item.width = 39; item.enabled = Qt.binding(() => header.controller && header.controller.directory.canGoForward); item.clicked.connect(() => header.controller.forward()); } }
        }
        Rectangle {
            Layout.preferredWidth: 300
            Layout.preferredHeight: 38
            radius: 19
            color: header.colors.card
            RowLayout {
                anchors.fill: parent; anchors.margins: 10; spacing: 15
                Icon.Tinted { source: "house.svg"; tint: header.colors.accent; Layout.preferredWidth: 18; Layout.preferredHeight: 18 }
                Text { text: "›"; color: header.colors.muted }
                Text { text: header.controller ? header.controller.title : ""; color: header.colors.ink; font.pixelSize: 13; font.bold: true; Layout.fillWidth: true; elide: Text.ElideMiddle }
                Item { Layout.fillWidth: true }
            }
        }
        Item { Layout.fillWidth: true }
        Rectangle {
            Layout.preferredWidth: Math.max(150, header.width * 0.29)
            Layout.preferredHeight: 40
            radius: 15
            color: header.colors.card
            border.color: header.colors.line
            Icon.Tinted { x: 14; y: 11; width: 18; height: 18; source: "search.svg"; tint: header.colors.ink }
            Text { anchors.left: parent.left; anchors.leftMargin: 44; anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter; text: qsTranslate("Pedro", "files.browser.search"); color: header.colors.muted; font.pixelSize: 13; elide: Text.ElideRight }
        }
        Loader { source: "button.qml"; onLoaded: item.symbol = "organization" }
        Loader { source: "button.qml"; onLoaded: item.text = "•••" }

    }
}
