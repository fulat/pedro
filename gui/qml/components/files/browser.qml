pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Pedro.Files 1.0
import "palette.js" as Palette

Rectangle {
    id: browser
    readonly property var colors: Palette.colors(Backend.appearanceMode)
    readonly property var controller: controllerLoader.item
    color: colors.surface

    Directory { id: directory; objectName: "filesDirectory" }
    Loader {
        id: controllerLoader
        source: "../../controllers/files/navigation.qml"
        onLoaded: item.directory = directory
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0
        Loader {
            Layout.preferredWidth: browser.controller && browser.controller.sidebarCollapsed ? 62 : 205
            Layout.fillHeight: true
            source: "sidebar.qml"
            onLoaded: item.controller = Qt.binding(() => browser.controller)
        }
        Rectangle { Layout.fillHeight: true; width: 1; color: browser.colors.line }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 17
            Layout.rightMargin: 16
            spacing: 8
            Loader { Layout.fillWidth: true; Layout.preferredHeight: 55; source: "toolbar.qml" }
            Text {
                visible: directory.error.length > 0
                Layout.fillWidth: true
                text: directory.error
                color: browser.colors.muted
                wrapMode: Text.WordWrap
            }
            ScrollView {
                id: contentScroll
                objectName: "filesBodyScroll"
                visible: !browser.controller || browser.controller.viewMode === "grid" || browser.controller.viewMode === "mixed"
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 0
                Layout.preferredHeight: 0
                clip: true
                contentWidth: availableWidth
                contentHeight: body.implicitHeight
                ScrollBar.vertical: ScrollBar {
                        orientation: Qt.Vertical
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 8
                        visible: size < 1
                        policy: ScrollBar.AsNeeded
                        contentItem: Rectangle {
                            implicitWidth: 6
                            implicitHeight: 6
                            radius: 3
                            color: "#c2bdba"
                            opacity: parent.pressed ? 1 : parent.hovered ? 0.9 : 0.7
                        }
                        background: Item {}
                    }
                ColumnLayout {
                    id: body
                    width: contentScroll.availableWidth
                    spacing: 12
                    GridView {
                        id: folderGrid
                        objectName: "filesFolderGrid"
                        visible: !browser.controller || browser.controller.viewMode !== "list"
                        readonly property bool mixed: !browser.controller || browser.controller.viewMode === "mixed"
                        readonly property int columns: Math.max(1, Math.floor(width / 120))
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.ceil(count / columns) * cellHeight
                        cellWidth: width / columns
                        cellHeight: 110
                        interactive: false
                        model: mixed ? directory.folderModel : directory.entriesModel
                        delegate: Loader {
                            id: entryCard
                            required property var entry
                            width: folderGrid.cellWidth - 8
                            height: 104
                            source: "card.qml"
                            onLoaded: { item.entry = Qt.binding(() => entryCard.entry); item.controller = Qt.binding(() => browser.controller); }
                        }
                    }
                    Loader {
                        visible: browser.controller && browser.controller.viewMode === "mixed" && browser.controller.files.length > 0
                        Layout.fillWidth: true
                        Layout.preferredHeight: item ? item.implicitHeight : 0
                        source: "table.qml"
                        onLoaded: {
                            item.controller = Qt.binding(() => browser.controller);
                            item.all = Qt.binding(() => browser.controller && browser.controller.viewMode === "list");
                        }
                    }
                    Text {
                        visible: !directory.loading && directory.rowCount() === 0 && !directory.error.length
                        Layout.fillWidth: true
                        text: qsTranslate("Pedro", "files.browser.empty")
                        color: browser.colors.muted
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
            Loader {
                visible: browser.controller && browser.controller.viewMode === "list"
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 0
                source: "table.qml"
                onLoaded: { item.controller = Qt.binding(() => browser.controller); item.all = true; item.embedded = false; }
            }
            Loader {
                visible: browser.controller && browser.controller.viewMode === "columns"
                active: visible
                Layout.fillWidth: true
                Layout.fillHeight: true
                source: "columns.qml"
                onLoaded: item.controller = Qt.binding(() => browser.controller)
            }
        }
    }
}
