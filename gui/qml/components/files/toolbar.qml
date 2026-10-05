pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "palette.js" as Palette

Item {
    id: toolbar
    readonly property var colors: Palette.colors(Backend.appearanceMode)
    property var controller
    readonly property bool trashMode: !!controller && String(controller.directory.location).startsWith("trash:")
    implicitHeight: 55
    RowLayout {
        anchors.fill: parent
        spacing: 7
        Repeater {
            model: toolbar.trashMode ? [] : ["all", "folders", "documents", "images"]
            delegate: Loader {
                id: filter
                required property string modelData
                source: "button.qml"
                onLoaded: {
                    item.text = Qt.binding(() => qsTranslate("Pedro", "files.browser." + filter.modelData));
                    item.primary = modelData === "all";
                    item.leftPadding = 8;
                    item.rightPadding = 8;
                    item.implicitWidth = Qt.binding(() => item.contentItem.implicitWidth + 16);
                    item.implicitHeight = 33;
                }
            }
        }
        Text {
            visible: toolbar.trashMode
            text: Backend.trash.busy ? qsTranslate("Pedro", "trash.busy") : toolbar.controller ? String(toolbar.controller.folders.length + toolbar.controller.files.length) + " " + qsTranslate("Pedro", "files.sample.itemsLabel") : ""
            color: toolbar.colors.ink
        }
        Item { Layout.fillWidth: true }
    }
}
