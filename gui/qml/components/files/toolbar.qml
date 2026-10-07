pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "palette.js" as Palette

Item {
    id: toolbar
    objectName: "filesTypeFilters"
    readonly property var colors: Palette.colors(Backend.appearanceMode)
    property var controller
    readonly property var directory: controller ? controller.viewMode === "columns" && controller.selectionModel ? controller.selectionModel : controller.directory : null
    readonly property var categoryKeys: directory ? directory.categories : []
    readonly property bool showFilters: categoryKeys.length > 1 && directory && !String(directory.location).startsWith("trash:")
    implicitHeight: showFilters ? 55 : 0
    Connections {
        target: toolbar.directory
        function onContentsChanged() {
            if (toolbar.directory && toolbar.directory.category !== "all"
                && (toolbar.categoryKeys.length < 2 || toolbar.categoryKeys.indexOf(toolbar.directory.category) < 0)) toolbar.directory.category = "all";
        }
    }
    Flickable {
        anchors.fill: parent
        contentWidth: filterRow.width
        contentHeight: height
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded; visible: size < 1 }
        Row {
            id: filterRow
            y: 11
            spacing: 7
            Repeater {
                model: toolbar.showFilters ? ["all"].concat(toolbar.categoryKeys) : []
                delegate: Loader {
                    id: filter
                    required property string modelData
                    objectName: "filesTypeFilter-" + modelData
                    width: item ? item.implicitWidth : 0
                    height: 33
                    source: "button.qml"
                    onLoaded: {
                        item.text = Qt.binding(() => qsTranslate("Pedro", "files.browser." + filter.modelData));
                        item.primary = Qt.binding(() => toolbar.directory && toolbar.directory.category === filter.modelData);
                        item.leftPadding = 8;
                        item.rightPadding = 8;
                        item.implicitWidth = Qt.binding(() => item.contentItem.implicitWidth + 16);
                        item.implicitHeight = 33;
                        item.clicked.connect(() => { if (toolbar.directory) toolbar.directory.category = filter.modelData; });
                    }
                }
            }
        }
    }
}
