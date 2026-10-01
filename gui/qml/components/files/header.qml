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
        Loader {
            source: "button.qml"
            onLoaded: {
                item.symbol = "window";
                item.clicked.connect(() => header.controller.sidebarCollapsed = !header.controller.sidebarCollapsed);
            }
        }
        Row {
            spacing: 8
            Loader { source: "button.qml"; onLoaded: { item.symbol = "back"; item.width = 39; item.enabled = Qt.binding(() => header.controller && header.controller.directory.canGoBack); item.clicked.connect(() => header.controller.back()); } }
            Loader { source: "button.qml"; onLoaded: { item.symbol = "forward"; item.width = 39; item.enabled = Qt.binding(() => header.controller && header.controller.directory.canGoForward); item.clicked.connect(() => header.controller.forward()); } }
        }
        Rectangle {
            visible: header.width >= 800
            Layout.preferredWidth: Math.max(105, Math.min(230, header.width * 0.22))
            Layout.preferredHeight: 38
            radius: 12
            color: header.colors.card
            RowLayout {
                anchors.fill: parent; anchors.margins: 10; spacing: 15
                Icon.Tinted { source: "house.svg"; tint: header.colors.accent; Layout.preferredWidth: 18; Layout.preferredHeight: 18 }
                Text { text: "›"; color: header.colors.muted }
                Text { text: header.controller ? header.controller.title : ""; color: header.colors.ink; font.pixelSize: 13; font.bold: true; Layout.fillWidth: true; elide: Text.ElideMiddle }
                Item { Layout.fillWidth: true }
            }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.minimumWidth: 120
            Layout.preferredHeight: 40
            radius: 12
            color: header.colors.card
            border.color: header.colors.line
            Icon.Tinted { x: 14; y: 11; width: 18; height: 18; source: "search.svg"; tint: header.colors.ink }
            Text { anchors.left: parent.left; anchors.leftMargin: 44; anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter; text: qsTranslate("Pedro", "files.browser.search"); color: header.colors.muted; font.pixelSize: 13; elide: Text.ElideRight }
        }
        Loader {
            source: "dropdown.qml"
            onLoaded: {
                item.symbol = Qt.binding(() => header.controller && header.controller.viewMode === "list" ? "list" : header.controller && header.controller.viewMode === "columns" ? "tab" : "grid");
                item.options = [{key: "grid", label: "files.view.grid"}, {key: "list", label: "files.view.list"}, {key: "columns", label: "files.view.columns"}, {key: "mixed", label: "files.view.mixed"}];
                item.selectedKey = Qt.binding(() => header.controller ? header.controller.viewMode : "mixed");
                item.chosen.connect(key => header.controller.viewMode = key);
            }
        }
        Loader {
            source: "dropdown.qml"
            onLoaded: {
                item.symbol = "sort";
                item.options = [{key: "name", label: "files.sample.name"}, {key: "type", label: "files.sample.type"}, {key: "size", label: "files.sample.size"}, {key: "modified", label: "files.sample.modified"}];
                item.selectedKey = Qt.binding(() => header.controller ? header.controller.sortKey : "name");
                item.chosen.connect(key => { header.controller.sortKey = key; header.controller.directory.setSort(key); });
            }
        }
    }
}
