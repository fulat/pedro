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
    property bool addingTag: false
    property string draftName: ""
    property string draftColor: "#0877ff"
    property string editingTag: ""
    property string paletteTag: ""
    property bool draftPalette: false
    property Item activeEditor: null
    readonly property var swatches: ["#0877ff", "#13c639", "#8e22ff", "#ffa100", "#ff6eaa", "#ef5b56", "#13b5b1", "#8496ab"]
    function addTag() {
        if (addingTag) return;
        if (!commitTag()) return;
        const base = qsTranslate("Pedro", "tags.new");
        let name = base, number = 2;
        while (Tags.tags.some(tag => tag.name.toLowerCase() === name.toLowerCase())) name = base + " " + number++;
        draftName = name;
        draftEditor.text = draftName;
        activeEditor = draftEditor;
        draftColor = swatches[Math.floor(Math.random() * swatches.length)];
        addingTag = true;
        draftPalette = true;
        Qt.callLater(() => { draftEditor.forceActiveFocus(); draftEditor.selectAll(); });
    }
    function commitTag() {
        if (Tags.busy) return false;
        if (addingTag) {
            const name = draftEditor.text.trim();
            const existing = Tags.tags.find(tag => tag.name.toLowerCase() === name.toLowerCase());
            const id = existing ? existing.id : Tags.create(name, draftColor);
            if (!id) return false;
            if (existing && existing.color !== draftColor) Tags.setColor(id, draftColor);
            Tags.assign(details.entry.url, id, true);
            addingTag = false;
            draftPalette = false;
        } else if (editingTag.length && activeEditor) {
            if (!Tags.rename(editingTag, activeEditor.text)) return false;
            editingTag = "";
        }
        return true;
    }
    Item {
        parent: details.Window.window ? details.Window.window.contentItem : null
        anchors.fill: parent
        z: 1000
        visible: details.addingTag || details.editingTag.length > 0
        PointHandler {
            acceptedButtons: Qt.AllButtons
            onActiveChanged: {
                if (!active || !details.activeEditor) return;
                const row = details.activeEditor.parent;
                const local = parent.mapToItem(row, point.position.x, point.position.y);
                const palettePoint = parent.mapToItem(tagPalette, point.position.x, point.position.y);
                if (!row.contains(local) && (!tagPalette.visible || !tagPalette.contains(palettePoint))) details.commitTag();
            }
        }
    }
    readonly property var assignedTags: { const revision = Tags.revision; return details.entry ? Tags.fileTags(details.entry.url) : []; }
    property var controller
    property var entry
    readonly property var colors: Palette.colors(Backend.appearanceMode)
    readonly property var metadata: information.data
    signal closeRequested()
    Connections { target: Tags; function onFileTagsChanged(source) { information.refresh(); } }
    Information { id: information; source: details.entry ? details.entry.url || "" : "" }

    function date(value) { return value && !isNaN(value.getTime()) ? value.toLocaleString(Qt.locale(), qsTranslate("Pedro", "files.info.dateformat")) : "—"; }
    function size() { return metadata.size !== undefined && !metadata.folder ? metadata.size + " " + qsTranslate("Pedro", "files.info.bytes") : "—"; }
    function permissions() {
        if (metadata.readable === undefined) return "—";
        return qsTranslate("Pedro", metadata.readable && metadata.writable ? "files.info.readwrite" : metadata.readable ? "files.info.read" : metadata.writable ? "files.info.write" : "files.info.none");
    }
    Controls.ScrollView {
        id: informationScroll
        Loader {
            source: "../scroll/edge.qml"
            onLoaded: item.flickable = Qt.binding(() => informationScroll.contentItem);
        }
        Binding { target: informationScroll.contentItem; property: "boundsBehavior"; value: Flickable.DragOverBounds }
        Binding { target: informationScroll.contentItem; property: "boundsMovement"; value: Flickable.StopAtBounds }
        objectName: "filesInformationContent"
        anchors.fill: parent
        anchors.margins: 14
        anchors.rightMargin: 22
        contentWidth: Math.max(availableWidth, details.columnMode ? 260 : 0)
        contentHeight: informationBody.implicitHeight + 20
        Controls.ScrollBar.vertical: Controls.ScrollBar {
            objectName: "filesInformationScrollBar"
            parent: details
            anchors.right: parent.right
            anchors.rightMargin: 1
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 8
            policy: Controls.ScrollBar.AsNeeded
            visible: size < 1
            interactive: true
            contentItem: Rectangle {
                implicitWidth: 6
                implicitHeight: 6
                radius: 3
                color: details.colors.light ? "#5e6b7c" : "#69798e"
                opacity: parent.pressed ? 1 : parent.hovered ? 0.9 : 0.7
            }
            background: Item {}
        }
        Controls.ScrollBar.horizontal.policy: Controls.ScrollBar.AlwaysOff
        clip: true
        Column {
            id: informationBody
            width: informationScroll.contentWidth
            spacing: 10
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
                width: parent.width; spacing: 10
                Text { text: qsTranslate("Pedro", "files.info.tags"); color: details.colors.ink; font.pixelSize: 13; font.weight: Font.Medium }
                Column {
                    width: parent.width; spacing: 6
                    Repeater {
                        model: details.assignedTags
                        delegate: Item {
                            id: tagRow
                            required property string modelData
                            readonly property var tag: { const revision = Tags.revision; return Tags.definition(modelData); }
                            width: parent.width; height: 32
                            Controls.ToolButton {
                                objectName: "informationTagColor-" + tagRow.modelData
                                width: 28; height: 28; y: 2
                                hoverEnabled: true
                                onClicked: { details.paletteTag = details.paletteTag === tagRow.modelData ? "" : tagRow.modelData; details.draftPalette = false; }
                                contentItem: Rectangle { radius: width / 2; color: tagRow.tag.color || details.colors.accent }
                                padding: 6
                                background: Rectangle { radius: 8; color: parent.hovered ? details.colors.hover : "transparent" }
                                HoverHandler { cursorShape: Qt.PointingHandCursor }
                            }
                            Controls.TextField {
                                id: tagName
                                objectName: "informationTagName-" + tagRow.modelData
                                x: 32; width: parent.width - 64; height: 32
                                readOnly: details.editingTag !== tagRow.modelData
                                text: tagRow.tag.name || tagRow.modelData
                                color: details.colors.ink; font.pixelSize: 12
                                padding: 5
                                selectionColor: "#555b91d1"; selectedTextColor: details.colors.ink
                                background: Rectangle { radius: 6; color: tagName.readOnly ? "transparent" : details.colors.card; border.color: tagName.readOnly ? "transparent" : details.colors.accent }
                                HoverHandler { cursorShape: tagName.readOnly ? Qt.PointingHandCursor : Qt.IBeamCursor }
                                TapHandler {
                                    onTapped: {
                                        if (details.editingTag === tagRow.modelData || !details.commitTag()) return;
                                        details.editingTag = tagRow.modelData;
                                        details.activeEditor = tagName;
                                        tagName.text = tagRow.tag.name || tagRow.modelData;
                                        tagName.forceActiveFocus(); tagName.selectAll();
                                    }
                                }
                                onReadOnlyChanged: if (readOnly) text = Qt.binding(() => tagRow.tag.name || tagRow.modelData)
                                onAccepted: details.commitTag()
                                Keys.onEscapePressed: details.editingTag = ""
                            }
                            Controls.ToolButton {
                                objectName: "informationTagRemove-" + tagRow.modelData
                                anchors.right: parent.right; width: 26; height: 32
                                text: "×"; enabled: !Tags.busy; hoverEnabled: true
                                palette.buttonText: details.colors.muted
                                onClicked: Tags.assign(details.entry.url, tagRow.modelData, false)
                                HoverHandler { cursorShape: Qt.PointingHandCursor }
                            }
                        }
                    }
                    Text { visible: !details.assignedTags.length; text: qsTranslate("Pedro", "files.info.untagged"); color: details.colors.muted; font.pixelSize: 12 }
                }
                Item {
                    width: parent.width; height: details.addingTag ? 34 : 0
                    visible: details.addingTag
                    Controls.ToolButton {
                        width: 28; height: 28; y: 3; hoverEnabled: true
                        onClicked: { details.draftPalette = !details.draftPalette; details.paletteTag = ""; }
                        contentItem: Rectangle { radius: width / 2; color: details.draftColor }
                        padding: 6
                        background: Rectangle { radius: 8; color: parent.hovered ? details.colors.hover : "transparent" }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                    }
                    Controls.TextField {
                        id: draftEditor
                        objectName: "informationNewTagName"
                        x: 32; width: parent.width - 32; height: 32
                        text: details.draftName
                        color: details.colors.ink; font.pixelSize: 12; padding: 5
                        selectionColor: "#555b91d1"; selectedTextColor: details.colors.ink
                        background: Rectangle { radius: 6; color: details.colors.card; border.color: details.colors.accent }
                        onVisibleChanged: if (visible) details.activeEditor = draftEditor
                        onTextEdited: {
                            const existing = Tags.tags.find(tag => tag.name.toLowerCase() === text.trim().toLowerCase());
                            if (existing) details.draftColor = existing.color;
                        }
                        onAccepted: details.commitTag()
                        Keys.onEscapePressed: { details.addingTag = false; details.draftPalette = false; }
                    }
                }
                Flow {
                    id: tagPalette
                    width: parent.width; spacing: 7
                    visible: details.draftPalette || details.paletteTag.length > 0
                    Repeater {
                        model: details.swatches
                        delegate: Rectangle {
                            required property string modelData
                            width: 20; height: 20; radius: 10; color: modelData
                            border.color: details.colors.line
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (details.draftPalette) details.draftColor = parent.modelData;
                                    else Tags.setColor(details.paletteTag, parent.modelData);
                                }
                            }
                        }
                    }
                }
                Controls.Button {
                    id: addTagButton
                    objectName: "informationAddTag"
                    text: "+  " + qsTranslate("Pedro", "files.info.addtag")
                    enabled: !Tags.busy && !details.addingTag
                    hoverEnabled: true
                    onClicked: details.addTag()
                    background: Rectangle { radius: 10; color: addTagButton.down ? details.colors.selected : addTagButton.hovered ? details.colors.hover : details.colors.card; border.color: details.colors.line; Behavior on color { ColorAnimation { duration: 120 } } }
                    contentItem: Text { text: addTagButton.text; color: details.colors.accent; font.pixelSize: 12 }
                    leftPadding: 12; rightPadding: 12; topPadding: 8; bottomPadding: 8
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                }
                Text { width: parent.width; visible: Tags.error.length > 0; text: Tags.error; color: details.colors.muted; wrapMode: Text.Wrap; font.pixelSize: 12 }
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
