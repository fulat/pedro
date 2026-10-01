pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../icon" as Icon
import "palette.js" as Palette

Column {
    id: table
    readonly property var colors: Palette.colors(Backend.appearanceMode)
    width: parent.width
    spacing: 0
    Row {
        width: parent.width; height: 33
        Repeater {
            model: [{key: "name", ratio: 0.28}, {key: "type", ratio: 0.18}, {key: "size", ratio: 0.115}, {key: "modified", ratio: 0.195}, {key: "tags", ratio: 0.18}]
            delegate: Text { required property var modelData; width: table.width * modelData.ratio; height: 33; verticalAlignment: Text.AlignVCenter; leftPadding: 7; text: qsTranslate("Pedro", "files.sample." + modelData.key) + (modelData.key === "name" ? "  ↑" : ""); color: table.colors.muted; font.pixelSize: 12 }
        }
    }
    Repeater {
        model: [{name: "roadmap.pdf", type: "pdf", size: "2.4 MB", date: "27 sep. 2025, 10:21", tag: "important", symbol: "pdf", tint: "#ff2424"}, {name: "logo-pedro.svg", type: "svg", size: "188 KB", date: "25 sep. 2025, 17:03", tag: "design", symbol: "logo", tint: "#111111"}, {name: "presentacion.pptx", type: "presentation", size: "6.8 MB", date: "23 sep. 2025, 12:11", tag: "work", symbol: "file", tint: "#eb4b16"}]
        delegate: Rectangle {
            id: row
            required property var modelData
            width: table.width; height: 43; radius: 9
            color: table.colors.card
            border.color: table.colors.line
            Row {
                anchors.fill: parent
                Item {
                    width: table.width * 0.28; height: parent.height
                    Icon.Tinted { x: 12; anchors.verticalCenter: parent.verticalCenter; width: 24; height: 28; source: row.modelData.symbol + ".svg"; tint: row.modelData.symbol === "logo" ? table.colors.ink : row.modelData.tint }
                    Text { x: 60; anchors.verticalCenter: parent.verticalCenter; text: row.modelData.name; color: table.colors.ink; font.pixelSize: 12; font.bold: true }
                }
                Text { width: table.width * 0.18; height: parent.height; verticalAlignment: Text.AlignVCenter; text: qsTranslate("Pedro", "files.sample." + row.modelData.type); color: table.colors.muted; font.pixelSize: 12 }
                Text { width: table.width * 0.115; height: parent.height; verticalAlignment: Text.AlignVCenter; text: row.modelData.size; color: table.colors.muted; font.pixelSize: 12 }
                Text { width: table.width * 0.195; height: parent.height; verticalAlignment: Text.AlignVCenter; text: row.modelData.date; color: table.colors.muted; font.pixelSize: 12 }
                Item {
                    width: table.width * 0.18; height: parent.height
                    Loader { anchors.verticalCenter: parent.verticalCenter; source: "badge.qml"; onLoaded: { item.text = Qt.binding(() => qsTranslate("Pedro", "files.sample." + row.modelData.tag)); item.tone = row.modelData.tag; } }
                }
                Text { text: "•••"; height: parent.height; verticalAlignment: Text.AlignVCenter; color: table.colors.ink }
            }
        }
    }
}
