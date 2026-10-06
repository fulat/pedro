pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtQuick.Controls.Basic as Controls
import Pedro.Files 1.0
import "../icon" as Icon
import "palette.js" as Palette

Item {
    id: details
    objectName: "filesColumnDetails"
    property bool columnMode: false
    property var controller
    property var entry
    readonly property var colors: Palette.colors(Backend.appearanceMode)
    readonly property var metadata: information.data
    signal closeRequested()
    Information { id: information; source: details.entry ? details.entry.url || "" : "" }

    function date(value) { return value && !isNaN(value.getTime()) ? value.toLocaleString(Qt.locale(), qsTranslate("Pedro", "files.info.dateformat")) : "—"; }
    function size() { return metadata.size !== undefined && !metadata.folder ? metadata.size + " " + qsTranslate("Pedro", "files.info.bytes") : "—"; }
    function permissions() {
        if (metadata.readable === undefined) return "—";
        return qsTranslate("Pedro", metadata.readable && metadata.writable ? "files.info.readwrite" : metadata.readable ? "files.info.read" : metadata.writable ? "files.info.write" : "files.info.none");
    }
    Controls.ScrollView {
        id: informationScroll
        objectName: "filesInformationContent"
        anchors.fill: parent
        anchors.margins: 14
        contentWidth: availableWidth
        Controls.ScrollBar.vertical.policy: Controls.ScrollBar.AsNeeded
        Controls.ScrollBar.vertical.interactive: true
        Controls.ScrollBar.horizontal.policy: Controls.ScrollBar.AlwaysOff
        clip: true
        Column {
            width: informationScroll.availableWidth
            spacing: 10
            Item {
                width: parent.width; height: 28
                Controls.ToolButton {
                    objectName: "filesInformationMenu"
                    anchors.right: parent.right
                    text: "⋯"
                    palette.buttonText: details.colors.ink
                    onClicked: more.open()
                    Controls.Menu {
                        id: more
                        popupType: Controls.Popup.Window
                        Controls.MenuItem { text: qsTranslate("Pedro", "files.info.refresh"); onTriggered: information.refresh() }
                        Controls.MenuItem { text: qsTranslate("Pedro", "files.info.close"); onTriggered: details.closeRequested() }
                    }
                }
            }
            Loader {
                width: 64; height: 64
                anchors.horizontalCenter: parent.horizontalCenter
                source: details.entry && details.entry.isDirectory ? "../entry/folder.qml" : "../entry/file.qml"
                onLoaded: {
                    item.entry = Qt.binding(() => details.entry || ({}));
                    item.controller = Qt.binding(() => details.controller);
                    item.iconSize = 64;
                    item.showName = false;
                    item.nameSurface = Qt.binding(() => nameSlot);
                    item.nameSize = 16;
                    item.textColor = Qt.binding(() => details.colors.ink);
                }
            }
            Item { id: nameSlot; width: parent.width; height: 34 }
            Text { width: parent.width; text: details.metadata.type || (details.entry ? details.entry.type || "" : ""); font.pixelSize: 13; color: details.colors.muted; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap }
            Text { width: parent.width; visible: information.error.length > 0; text: information.error; color: details.colors.muted; wrapMode: Text.Wrap; font.pixelSize: 12 }
            Divider {}
            Repeater {
                model: [{label: "files.sample.type", icon: "file", value: details.metadata.type || "—"},
                        {label: "files.sample.size", icon: "size", value: details.size()},
                        {label: "files.info.location", icon: "folder", value: details.metadata.location || "—"}]
                delegate: Field { required property var modelData; label: modelData.label; symbol: modelData.icon; value: modelData.value }
            }
            Divider {}
            Repeater {
                model: [{label: "files.info.created", icon: "calendar", value: details.date(details.metadata.created)},
                        {label: "files.sample.modified", icon: "calendar", value: details.date(details.metadata.modified)},
                        {label: "files.info.accessed", icon: "clock", value: details.date(details.metadata.accessed)}]
                delegate: Field { required property var modelData; label: modelData.label; symbol: modelData.icon; value: modelData.value }
            }
            Divider {}
            Column {
                width: parent.width; spacing: 8
                Text { text: qsTranslate("Pedro", "files.info.tags"); color: details.colors.ink; font.pixelSize: 13; font.weight: Font.Medium }
                Flow {
                    width: parent.width; spacing: 8
                    Repeater {
                        model: details.metadata.tags || []
                        delegate: Rectangle {
                            required property string modelData
                            width: tagLabel.implicitWidth + 24; height: 30; radius: 15
                            color: details.colors.accent
                            Text { id: tagLabel; anchors.centerIn: parent; text: parent.modelData; color: "white"; font.pixelSize: 12 }
                        }
                    }
                    Text { visible: !(details.metadata.tags || []).length; text: qsTranslate("Pedro", "files.info.untagged"); color: details.colors.muted; font.pixelSize: 12 }
                }
                Flow {
                    width: parent.width; spacing: 10
                    Controls.Button {
                        text: "+  " + qsTranslate("Pedro", "files.info.addtag"); enabled: false
                        background: Rectangle { radius: 17; color: "transparent"; border.color: details.colors.line }
                        contentItem: Text { text: parent.text; color: details.colors.muted; font.pixelSize: 12; opacity: 0.6 }
                        leftPadding: 14; rightPadding: 14; topPadding: 8; bottomPadding: 8
                    }
                    Controls.Button {
                        text: qsTranslate("Pedro", "files.info.edittags"); enabled: false
                        background: Item {}
                        contentItem: Text { text: parent.text; color: details.colors.accent; font.pixelSize: 12; opacity: 0.6 }
                        topPadding: 8; bottomPadding: 8
                    }
                }
            }
            Divider {}
            Field { label: "files.info.owner"; symbol: "user"; value: details.metadata.owner || "—" }
            Field { label: "files.info.permissions"; symbol: "lock"; value: details.permissions() }
        }
    }
    component Divider: Rectangle { width: parent.width; height: 1; color: details.colors.line }
    component Field: Item {
        property string label
        property string symbol
        property string value
        width: parent.width
        readonly property bool compact: details.width < 300
        height: compact ? labelText.implicitHeight + valueLabel.implicitHeight + 10 : Math.max(28, labelText.implicitHeight, valueLabel.implicitHeight)
        Icon.Tinted { width: 20; height: 20; anchors.verticalCenter: parent.verticalCenter; source: "../../../assets/icons/" + parent.symbol + ".svg"; tint: details.colors.ink }
        Text { id: labelText; x: 32; width: parent.compact ? parent.width - 32 : parent.width * 0.4 - 32; y: parent.compact ? 0 : (parent.height - height) / 2; text: qsTranslate("Pedro", parent.label); color: details.colors.ink; font.pixelSize: 13; wrapMode: Text.Wrap }
        Text { id: valueLabel; x: parent.compact ? 32 : parent.width * 0.42; y: parent.compact ? labelText.implicitHeight + 6 : (parent.height - height) / 2; width: parent.width - x; text: parent.value; maximumLineCount: 2; elide: Text.ElideMiddle; color: details.colors.muted; font.pixelSize: 13; horizontalAlignment: parent.compact ? Text.AlignLeft : Text.AlignRight; wrapMode: Text.Wrap }
    }
}
