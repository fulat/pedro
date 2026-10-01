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
            Layout.preferredWidth: 205
            Layout.fillHeight: true
            source: "sidebar.qml"
            onLoaded: item.controller = Qt.binding(() => browser.controller)
        }
        ScrollView {
            id: contentScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 17
            Layout.rightMargin: 16
            clip: true
            contentWidth: availableWidth
            ScrollBar.vertical.policy: ScrollBar.AsNeeded
            ColumnLayout {
                width: contentScroll.availableWidth
                spacing: 15
                Loader { Layout.fillWidth: true; Layout.preferredHeight: 55; source: "toolbar.qml" }
                Loader { Layout.fillWidth: true; Layout.preferredHeight: 115; source: "banner.qml"; onLoaded: item.controller = Qt.binding(() => browser.controller) }
                Text {
                    Layout.fillWidth: true
                    visible: directory.error.length > 0
                    text: directory.error
                    color: browser.colors.muted
                    wrapMode: Text.WordWrap
                }
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: qsTranslate("Pedro", "files.browser.folders") + "  (" + (browser.controller ? browser.controller.folders.length : 0) + ")"; color: browser.colors.ink; font.pixelSize: 17; font.bold: true }
                    Item { Layout.fillWidth: true }
                    Text { text: qsTranslate("Pedro", "files.sample.sort") + "  ⌄"; color: browser.colors.muted; font.pixelSize: 12 }
                    Loader { source: "button.qml"; onLoaded: item.symbol = "grid" }
                    Loader { source: "button.qml"; onLoaded: item.symbol = "list" }
                }
                GridView {
                    id: folderGrid
                    objectName: "filesFolderGrid"
                    readonly property int columns: browser.width >= 1100 ? 4 : browser.width >= 880 ? 3 : 2
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(Math.ceil(count / columns) * cellHeight, 310)
                    cellWidth: width / columns
                    cellHeight: 101
                    clip: true
                    model: directory.folderModel
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                    delegate: Loader {
                        id: folder
                        required property var entry
                        width: folderGrid.cellWidth - 9
                        height: 92
                        source: "card.qml"
                        onLoaded: {
                            item.entry = Qt.binding(() => folder.entry);
                            item.controller = Qt.binding(() => browser.controller);
                        }
                    }
                }
                Rectangle { Layout.fillWidth: true; height: 1; color: browser.colors.line }
                Text { text: qsTranslate("Pedro", "files.sample.files") + "  (" + (browser.controller ? browser.controller.files.length : 0) + ")"; color: browser.colors.ink; font.pixelSize: 17; font.bold: true }
                Loader {
                    Layout.fillWidth: true
                    Layout.preferredHeight: item ? item.implicitHeight : 33
                    source: "table.qml"
                    onLoaded: item.controller = Qt.binding(() => browser.controller)
                }
                Text {
                    Layout.fillWidth: true
                    visible: !directory.loading && directory.rowCount() === 0 && !directory.error.length
                    text: qsTranslate("Pedro", "files.browser.empty")
                    color: browser.colors.muted
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
        Rectangle { Layout.fillHeight: true; width: 1; color: browser.colors.line }
        Loader {
            Layout.preferredWidth: 218
            Layout.fillHeight: true
            Layout.leftMargin: 14
            Layout.rightMargin: 14
            Layout.topMargin: 16
            source: "inspector.qml"
            onLoaded: item.controller = Qt.binding(() => browser.controller)
        }
    }
}
