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
    readonly property real trailingWidth: 278 + (showEmpty ? emptyTrash.contentItem.implicitWidth + 40 : 0)
    readonly property real locationMinimumWidth: Math.min(220, Math.max(110, width - (searchExpanded ? 220 : 44) - header.trailingWidth))
    readonly property string currentPath: controller && controller.directory ? controller.directory.path || controller.directory.location : ""
    readonly property bool showEmpty: !!controller && controller.directory.place === "trash" && !(controller.directory.globalSearch && controller.directory.search.trim().length) && controller.directory.count > 0
    property var controller
    readonly property var colors: Palette.colors(Backend.appearanceMode)
    TextMetrics {
        id: nameMetrics
        font.pixelSize: 13
        font.bold: true
        text: header.controller ? header.controller.title : ""
    }
    TextMetrics {
        id: pathMetrics
        font.pixelSize: 13
        text: header.currentPath
    }
    Item {
        parent: header.Window.window ? header.Window.window.contentItem : null
        anchors.fill: parent
        z: 1000
        PointHandler {
            acceptedButtons: Qt.AllButtons
            onActiveChanged: {
                if (active && header.pathExpanded) {
                    const local = parent.mapToItem(location, point.position.x, point.position.y);
                    if (!location.contains(local)) header.pathExpanded = false;
                }
                if (active && header.searchExpanded) {
                    const local = parent.mapToItem(searchInput, point.position.x, point.position.y);
                    if (!searchInput.contains(local) && !searchInput.text.length) header.searchExpanded = false;
                }
            }
        }
    }
    Connections {
        target: header.Window.window
        function onActiveChanged() {
            if (!header.Window.window || !header.Window.window.active) {
                header.pathExpanded = false;
                if (!searchInput.text.length) header.searchExpanded = false;
            }
        }
    }
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
            Layout.minimumWidth: header.locationMinimumWidth
            Layout.maximumWidth: Math.max(header.locationMinimumWidth, Math.min(header.pathExpanded ? 480 : 320, header.width - (header.searchExpanded ? 220 : 44) - header.trailingWidth))
            Layout.preferredWidth: Math.min(Layout.maximumWidth, Math.max(header.locationMinimumWidth, header.pathExpanded ? pathMetrics.advanceWidth + 20 : nameMetrics.advanceWidth + 50))
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
        Item { Layout.fillWidth: true }
        Loader {
            visible: !header.searchExpanded
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
            text: header.controller ? header.controller.directory.search : ""
            onTextEdited: { if (header.controller) header.controller.directory.search = text; }
            placeholderText: qsTranslate("Pedro", "files.browser.search")
            color: header.colors.ink
            placeholderTextColor: header.colors.muted
            selectByMouse: true
            font.pixelSize: 13
            leftPadding: 38
            Keys.onEscapePressed: { if (header.controller) header.controller.directory.search = ""; header.searchExpanded = false; focus = false; }
            Icon.Tinted {
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 18
                height: 18
                source: "search.svg"
                tint: header.colors.muted
            }
            background: Rectangle { radius: 10; color: header.colors.card; border.color: header.colors.line }
        }
        Loader {
            source: "dropdown.qml"
            onLoaded: {
                item.objectName = "filesViewDropdown";
                item.symbol = "view";
                item.options = [{key: "grid", icon: "grid", label: "files.view.grid"}, {key: "list", icon: "list", label: "files.view.list"}, {key: "columns", icon: "columns", label: "files.view.columns"}, {key: "mixed", icon: "mixed", label: "files.view.mixed"}];
                item.selectedKey = Qt.binding(() => header.controller ? header.controller.viewMode : "mixed");
                item.chosen.connect(key => header.controller.viewMode = key);
            }
        }
        Loader {
            source: "dropdown.qml"
            onLoaded: {
                item.objectName = "filesSortDropdown";
                item.symbol = "sort";
                item.options = [{key: "name", icon: "sort", label: "files.sample.name"}, {key: "type", icon: "file", label: "files.sample.type"}, {key: "size", icon: "size", label: "files.sample.size"}, {key: "modified", icon: "calendar", label: "files.sample.modified"}];
                item.selectedKey = Qt.binding(() => header.controller ? header.controller.sortKey : "name");
                item.chosen.connect(key => { header.controller.sortKey = key; header.controller.directory.setSort(key); });
            }
        }
        Button {
            id: emptyTrash
            objectName: "trashEmpty"
            visible: header.showEmpty
            enabled: !Backend.trash.busy
            Layout.preferredHeight: 32
            Layout.preferredWidth: contentItem.implicitWidth + 28
            hoverEnabled: true
            text: qsTranslate("Pedro", "trash.empty")
            Accessible.name: text
            onClicked: header.controller.emptyRequested()
            contentItem: Row {
                spacing: 7
                Icon.Tinted {
                    width: 15; height: 15
                    anchors.verticalCenter: parent.verticalCenter
                    source: "trash.svg"
                    tint: header.colors.ink
                }
                Text {
                    text: emptyTrash.text
                    color: header.colors.ink
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            background: Item {
                opacity: emptyTrash.enabled ? 1 : 0.45
                Loader {
                    anchors.fill: parent
                    source: "../entry/surface.qml"
                    onLoaded: {
                        item.sourceBackdrop = Qt.binding(() => header.Window.window ? header.Window.window.entryBackdrop : null);
                        item.frosted = true;
                        item.cornerRadius = 10;
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: emptyTrash.down ? header.colors.selected : emptyTrash.hovered ? header.colors.hover : "transparent"
                    border.color: header.colors.line
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
            }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
        }
    }
}
