pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../desktop" as Desktop
import "palette.js" as Palette

Rectangle {
    id: banner
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
                Text { text: qsTranslate("Pedro", "files.browser.project"); color: banner.colors.ink; font.pixelSize: 20; font.bold: true }
                Text { text: "★"; color: "#ffb512"; font.pixelSize: 22 }
            }
            Text { text: qsTranslate("Pedro", "files.sample.summary"); color: banner.colors.muted; font.pixelSize: 13 }
            Text { text: qsTranslate("Pedro", "files.sample.description"); color: banner.colors.muted; font.pixelSize: 13; Layout.fillWidth: true; elide: Text.ElideRight }
        }
        Column {
            Layout.preferredWidth: 185
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: 9
            spacing: 8
            Text { text: qsTranslate("Pedro", "files.sample.storage"); color: banner.colors.muted; font.pixelSize: 12 }
            Rectangle { width: 185; height: 8; radius: 4; color: "#bdd1ed"; Rectangle { width: 50; height: 8; radius: 4; color: banner.colors.accent } }
        }
    }
}
