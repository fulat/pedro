pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import Pedro.Files 1.0
import "../desktop" as Desktop
import "palette.js" as Palette

ScrollView {
    id: columns
    objectName: "filesColumns"
    property var controller
    property var locations: controller && controller.directory ? [controller.directory.location] : []
    readonly property var colors: Palette.colors(Backend.appearanceMode)
    clip: true
    contentHeight: availableHeight
    ScrollBar.horizontal.policy: ScrollBar.AsNeeded
    Connections {
        target: columns.controller ? columns.controller.directory : null
        function onLocationChanged() { columns.locations = [columns.controller.directory.location]; }
    }
    Row {
        height: columns.availableHeight
        Repeater {
            model: columns.locations
            delegate: Item {
                id: column
                required property string modelData
                required property int index
                property string selected: ""
                width: 240
                height: parent.height
                Directory {
                    id: directory
                    Component.onCompleted: { open(column.modelData); setSort(columns.controller.sortKey); }
                }
                Connections {
                    target: columns.controller
                    function onSortKeyChanged() { directory.setSort(columns.controller.sortKey); }
                }
                ListView {
                    anchors.fill: parent
                    anchors.rightMargin: 9
                    clip: true
                    model: directory.entriesModel
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                    delegate: Rectangle {
                        id: row
                        objectName: "filesColumn-" + column.index + "-" + entry.name
                        required property var entry
                        width: ListView.view.width
                        height: 38
                        radius: 7
                        color: column.selected === entry.id || columns.locations[column.index + 1] === entry.url ? columns.colors.selected : "transparent"
                        Desktop.Icon { x: 8; y: 5; width: 28; height: 28; kind: row.entry.icon || "file" }
                        Text { x: 44; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 62; text: row.entry.name; color: columns.colors.ink; font.pixelSize: 12; elide: Text.ElideMiddle }
                        Text { visible: row.entry.isDirectory; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: "›"; color: columns.colors.muted }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                column.selected = row.entry.id;
                                columns.controller.select(row.entry);
                                const locations = columns.locations.slice(0, column.index + 1);
                                if (row.entry.isDirectory) locations.push(row.entry.url);
                                columns.locations = locations;
                            }
                        }
                    }
                }
                Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: columns.colors.line }
            }
        }
    }
}
