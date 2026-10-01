pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../desktop" as Desktop
import "palette.js" as Palette

Rectangle {
    id: banner
    property var controller
    readonly property var colors: Palette.colors(Backend.appearanceMode)
    implicitHeight: 115
    radius: 12
    color: colors.banner
    clip: true
    // Decorative landscape is part of the project summary, not the wallpaper setting.
    Loader { anchors.right: parent.right; width: 235; height: parent.height; source: "landscape.qml"; opacity: 0.9 }
    RowLayout {
        anchors.fill: parent; anchors.margins: 18; spacing: 20
        Desktop.Icon { kind: "folder"; Layout.preferredWidth: 90; Layout.preferredHeight: 90 }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            RowLayout {
                Layout.fillWidth: true
                Text { text: banner.controller ? banner.controller.title : ""; color: banner.colors.ink; font.pixelSize: 20; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
            }
            Text { text: banner.controller ? qsTranslate("Pedro", "files.sample.items").arg(banner.controller.folders.length + banner.controller.files.length) : ""; color: banner.colors.muted; font.pixelSize: 13 }
            Text { text: banner.controller ? banner.controller.directory.path || banner.controller.title : ""; color: banner.colors.muted; font.pixelSize: 13; Layout.fillWidth: true; elide: Text.ElideRight }
        }
    }
}
