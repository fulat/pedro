pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "palette.js" as Palette

// Reference layout with sample data only; filesystem navigation remains in PAPI.
Rectangle {
    id: browser
    readonly property var colors: Palette.colors(Backend.appearanceMode)
    color: colors.surface
    RowLayout {
        anchors.fill: parent
        spacing: 0
        Loader {
            Layout.preferredWidth: 205
            Layout.fillHeight: true
            source: "sidebar.qml"
        }
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 17
            Layout.rightMargin: 16
            clip: true
            contentWidth: availableWidth
            ColumnLayout {
                width: parent.width
                spacing: 15
                Loader { Layout.fillWidth: true; Layout.preferredHeight: 55; source: "toolbar.qml" }
                Loader { Layout.fillWidth: true; Layout.preferredHeight: 115; source: "banner.qml" }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 1
                    Text { text: qsTranslate("Pedro", "files.browser.folders") + "  (7)"; color: browser.colors.ink; font.pixelSize: 17; font.bold: true }
                    Item { Layout.fillWidth: true }
                    Text { text: qsTranslate("Pedro", "files.sample.sort") + "  ⌄"; color: browser.colors.muted; font.pixelSize: 12 }
                    Loader { source: "button.qml"; onLoaded: item.symbol = "grid" }
                    Loader { source: "button.qml"; onLoaded: item.symbol = "list" }
                }
                GridLayout {
                    Layout.fillWidth: true
                    columns: browser.width >= 1100 ? 4 : browser.width >= 880 ? 3 : 2
                    columnSpacing: 9
                    rowSpacing: 9
                    Repeater {
                        model: [
                            {name: "designs", count: 12, size: "4.2 GB", tag: "design"}, {name: "wallpapers", count: 24, size: "3.6 GB", tag: "work"},
                            {name: "contracts", count: 4, size: "532 MB", tag: ""}, {name: "mockups", count: 15, size: "2.1 GB", tag: "design"},
                            {name: "captures", count: 8, size: "1.4 GB", tag: ""}, {name: "resources", count: 9, size: "1.1 GB", tag: "work"},
                            {name: "references", count: 6, size: "893 MB", tag: "important"}
                        ]
                        delegate: Loader {
                            id: folder
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 112
                            source: "card.qml"
                            onLoaded: item.entry = modelData
                        }
                    }
                }
                Rectangle { Layout.fillWidth: true; height: 1; color: browser.colors.line }
                Text { text: qsTranslate("Pedro", "files.sample.files") + "  (3)"; color: browser.colors.ink; font.pixelSize: 17; font.bold: true }
                Loader { Layout.fillWidth: true; Layout.preferredHeight: 162; source: "table.qml" }
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
        }
    }
}
