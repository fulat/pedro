pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "../icon" as Icon
import "palette.js" as Palette

Item {
    id: header
    property bool searchExpanded: false
    property bool pathExpanded: false
    readonly property string currentPath: controller && controller.directory ? controller.directory.path || controller.directory.location : ""
    property var controller
    readonly property var colors: Palette.colors(Backend.appearanceMode)
    RowLayout {
        anchors.fill: parent
        anchors.rightMargin: 24
        spacing: 12
        Row {
            spacing: 8
            Loader { source: "button.qml"; onLoaded: { item.symbol = "back"; item.width = 39; item.enabled = Qt.binding(() => header.controller && header.controller.directory.canGoBack); item.clicked.connect(() => header.controller.back()); } }
            Loader { source: "button.qml"; onLoaded: { item.symbol = "forward"; item.width = 39; item.enabled = Qt.binding(() => header.controller && header.controller.directory.canGoForward); item.clicked.connect(() => header.controller.forward()); } }
        }
        Rectangle {
            id: location
            objectName: "filesLocation"
            Layout.fillWidth: true
            Layout.minimumWidth: 110
            Layout.preferredWidth: 240
            Layout.preferredHeight: 38
            radius: 12
            color: header.colors.card
            Icon.Tinted { visible: !header.pathExpanded; x: 12; anchors.verticalCenter: parent.verticalCenter; width: 18; height: 18; source: "folder.svg"; tint: header.colors.accent }
            Text {
                visible: !header.pathExpanded
                anchors.left: parent.left
                anchors.leftMargin: 40
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: header.controller ? header.controller.title : ""
                color: header.colors.ink
                font.pixelSize: 13
                font.bold: true
                elide: Text.ElideMiddle
            }
            MouseArea {
                anchors.fill: parent
                enabled: !header.pathExpanded
                cursorShape: Qt.IBeamCursor
                onClicked: {
                    header.pathExpanded = true;
                    pathInput.text = header.currentPath;
                    pathInput.forceActiveFocus();
                    pathInput.selectAll();
                }
            }
            TextField {
                id: pathInput
                objectName: "filesPathInput"
                anchors.fill: parent
                visible: header.pathExpanded
                text: header.currentPath
                readOnly: true
                selectByMouse: true
                color: header.colors.ink
                font.pixelSize: 13
                leftPadding: 10
                rightPadding: 10
                background: Item {}
                onActiveFocusChanged: { if (!activeFocus) header.pathExpanded = false; }
                Keys.onEscapePressed: { header.pathExpanded = false; focus = false; }
            }
        }
        Loader {
            source: "button.qml"
            onLoaded: {
                item.objectName = "filesSearchButton";
                item.symbol = "search";
                item.clicked.connect(() => { header.searchExpanded = !header.searchExpanded; if (header.searchExpanded) searchInput.forceActiveFocus(); });
            }
        }
        TextField {
            id: searchInput
            objectName: "filesSearchInput"
            visible: header.searchExpanded
            Layout.preferredWidth: 220
            Layout.minimumWidth: 220
            Layout.maximumWidth: 220
            Layout.preferredHeight: 38
            placeholderText: qsTranslate("Pedro", "files.browser.search")
            color: header.colors.ink
            placeholderTextColor: header.colors.muted
            selectByMouse: true
            font.pixelSize: 13
            background: Rectangle { radius: 10; color: header.colors.card; border.color: header.colors.line }
        }
        Loader {
            source: "dropdown.qml"
            onLoaded: {
                item.symbol = Qt.binding(() => header.controller && header.controller.viewMode === "list" ? "list" : header.controller && header.controller.viewMode === "columns" ? "columns" : header.controller && header.controller.viewMode === "mixed" ? "mixed" : "grid");
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
