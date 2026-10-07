pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Pedro.Files 1.0
import "../icon" as Icon
import "palette.js" as Palette

Rectangle {
    id: sidebar
    property var controller
    property string editingTag: ""
    property string colorTag: ""
    property Item editingField: null
    property string contextTag: ""
    readonly property var swatches: ["#0877ff", "#13c639", "#8e22ff", "#ffa100", "#ff6eaa", "#ef5b56", "#13b5b1", "#8496ab"]
    readonly property var colors: Palette.colors(Backend.appearanceMode)
    readonly property bool collapsed: !!controller && controller.sidebarCollapsed
    color: "transparent"
    Connections {
        target: Tags
        function onChanged() {
            if (sidebar.controller && sidebar.controller.directory && String(sidebar.controller.directory.location).startsWith("pedro:tag:")
                && !Tags.definition(String(sidebar.controller.directory.location).slice(10)).id) sidebar.controller.openPlace("home");
        }
    }
    function finishName() {
        if (editingField && editingTag.length && Tags.rename(editingTag, editingField.text)) editingTag = "";
    }
    function addTag() {
        finishName();
        const base = qsTranslate("Pedro", "tags.new");
        let name = base, number = 2;
        while (Tags.tags.some(tag => tag.name.toLowerCase() === name.toLowerCase())) name = base + " " + number++;
        const id = Tags.create(name, swatches[Tags.tags.length % swatches.length]);
        if (!id.length) return;
        editingTag = id;
        colorTag = id;
        Qt.callLater(() => tagList.positionViewAtEnd());
    }
    Item {
        parent: sidebar.Window.window ? sidebar.Window.window.contentItem : null
        anchors.fill: parent
        z: 1000
        visible: sidebar.editingTag.length > 0
        PointHandler {
            acceptedButtons: Qt.AllButtons
            onActiveChanged: {
                if (!active || !sidebar.editingField) return;
                const row = sidebar.editingField.parent;
                const local = parent.mapToItem(row, point.position.x, point.position.y);
                if (!row.contains(local)) sidebar.finishName();
            }
        }
    }
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: sidebar.collapsed ? 7 : 14
        spacing: 0
        ScrollView {
            id: sidebarScroll
            Layout.fillWidth: true
            Layout.preferredHeight: navigation.implicitHeight
            Layout.maximumHeight: Math.max(0, sidebar.height - (sidebar.collapsed ? 14 : 150))
            ScrollBar.vertical.policy: ScrollBar.AsNeeded
            ScrollBar.vertical.visible: ScrollBar.vertical.size < 1
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            Binding { target: sidebarScroll.contentItem; property: "boundsBehavior"; value: Flickable.StopAtBounds }
            clip: true
            contentWidth: availableWidth
            contentHeight: navigation.implicitHeight
            Column {
                id: navigation
                width: sidebarScroll.availableWidth
                spacing: 0
            Repeater {
                model: [
                    {name: "home", icon: "house"}, {name: "favorites", icon: "star"}, {name: "recent", icon: "clock"},
                    {divider: true},
                    {name: "desktop", icon: "display"}, {name: "documents", icon: "file"}, {name: "downloads", icon: "download"}, {name: "images", icon: "image"}, {name: "music", icon: "music"}, {name: "videos", icon: "video"},
                    {divider: true},
                    {name: "computer", icon: "display"}, {divider: true}
                ]
                delegate: Item {
                    id: row
                    required property var modelData
                    objectName: modelData.name ? "filesPlace-" + modelData.name : ""
                    width: parent.width
                    height: modelData.divider ? 23 : 36
                    Rectangle {
                        visible: row.modelData.divider === true
                        width: parent.width - 12
                        x: 6
                        y: 11
                        height: 1
                        color: sidebar.colors.line
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: 18
                        visible: !row.modelData.divider
                        color: sidebar.controller && row.modelData.name === sidebar.controller.activePlace ? sidebar.colors.selected : rowHover.hovered ? sidebar.colors.hover : "transparent"
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: !row.modelData.divider
                        onClicked: sidebar.controller.openPlace(row.modelData.name)
                        onDoubleClicked: sidebar.controller.resetPlace(row.modelData.name)
                    }
                    HoverHandler { id: rowHover; enabled: !row.modelData.divider; cursorShape: Qt.PointingHandCursor }
                    Icon.Tinted {
                        visible: !row.modelData.divider
                        x: 14; y: 8; width: 20; height: 20
                        source: row.modelData.icon ? row.modelData.icon + ".svg" : ""
                        tint: row.modelData.name === "home" ? sidebar.colors.accent : sidebar.colors.ink
                    }
                    Text {
                        visible: !row.modelData.divider && !(sidebar.controller && sidebar.controller.sidebarCollapsed)
                        x: 49
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.name ? qsTranslate("Pedro", "files.browser." + row.modelData.name) : ""
                        color: sidebar.colors.ink
                        font.pixelSize: 14
                        font.bold: sidebar.controller && row.modelData.name === sidebar.controller.activePlace
                    }
                }
            }
            }
        }
        Item {
            visible: !sidebar.collapsed
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 38 : 0
            Text { anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: qsTranslate("Pedro", "files.sample.tags"); color: sidebar.colors.muted; font.pixelSize: 13 }
            ToolButton {
                objectName: "tagsAdd"
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 28; height: 28
                hoverEnabled: true
                Accessible.name: qsTranslate("Pedro", "tags.new")
                onClicked: sidebar.addTag()
                contentItem: Item {
                    Rectangle { anchors.centerIn: parent; width: 12; height: 1.5; radius: 0.75; color: sidebar.colors.accent }
                    Rectangle { anchors.centerIn: parent; width: 1.5; height: 12; radius: 0.75; color: sidebar.colors.accent }
                }
                background: Rectangle { radius: 10; color: parent.hovered ? sidebar.colors.selected : sidebar.colors.card; border.color: sidebar.colors.line }
            }
        }
        ListView {
            id: tagList
            objectName: "tagsList"
            visible: !sidebar.collapsed
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: visible ? 50 : 0
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: Tags
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; visible: size < 1 }
            delegate: Item {
                id: tagRow
                required property string tagId
                required property string tagName
                required property string tagColor
                objectName: "tag-" + tagId
                width: tagList.width - 10
                height: 33 + (sidebar.colorTag === tagId ? 54 : 0)
                Rectangle { width: parent.width; height: 32; radius: 10; color: sidebar.controller && sidebar.controller.currentTag.id === tagRow.tagId ? sidebar.colors.selected : tagHover.hovered ? sidebar.colors.hover : "transparent" }
                MouseArea {
                    width: parent.width; height: 33
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: mouse => {
                        sidebar.finishName();
                        if (mouse.button === Qt.RightButton) { sidebar.contextTag = tagRow.tagId; tagMenu.popup(tagRow, mouse.x, mouse.y); }
                        else if (sidebar.controller) sidebar.controller.openTag(tagRow.tagId);
                    }
                }
                HoverHandler { id: tagHover; cursorShape: Qt.PointingHandCursor }
                Rectangle { x: 14; y: 9; width: 15; height: 15; radius: 7.5; color: tagRow.tagColor }
                Text { x: 42; y: 0; height: 33; width: parent.width - 48; verticalAlignment: Text.AlignVCenter; visible: sidebar.editingTag !== tagRow.tagId; text: tagRow.tagName; color: sidebar.colors.ink; font.pixelSize: 13; elide: Text.ElideRight }
                TextField {
                    id: nameEditor
                    objectName: "tagEditor-" + tagRow.tagId
                    x: 38; y: 2; width: parent.width - 42; height: 29
                    visible: sidebar.editingTag === tagRow.tagId
                    text: tagRow.tagName
                    color: sidebar.colors.ink
                    selectionColor: "#555b91d1"
                    selectedTextColor: sidebar.colors.ink
                    font.pixelSize: 13
                    padding: 4
                    background: Rectangle { radius: 6; color: sidebar.colors.card; border.color: sidebar.colors.accent }
                    function beginEdit() {
                        sidebar.editingField = nameEditor;
                        nameEditor.text = tagRow.tagName;
                        Qt.callLater(() => { nameEditor.forceActiveFocus(); nameEditor.selectAll(); });
                    }
                    onVisibleChanged: if (visible) beginEdit()
                    Component.onCompleted: if (visible) beginEdit()
                    onAccepted: sidebar.finishName()
                    Keys.onEscapePressed: sidebar.editingTag = ""
                }
                Flow {
                    id: palette
                    visible: sidebar.colorTag === tagRow.tagId
                    x: 12; y: 37; width: parent.width - 20; spacing: 7
                    onVisibleChanged: if (visible) sidebar.colorField = palette;
                    Repeater {
                        model: sidebar.swatches
                        delegate: Rectangle {
                            required property string modelData
                            objectName: "tagColor-" + tagRow.tagId + "-" + modelData
                            width: 20; height: 20; radius: 10
                            color: modelData
                            border.width: tagRow.tagColor === modelData ? 2 : 1
                            border.color: tagRow.tagColor === modelData ? sidebar.colors.ink : sidebar.colors.line
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Tags.setColor(tagRow.tagId, parent.modelData) }
                        }
                    }
                }
            }
        }
        Text { Layout.fillWidth: true; visible: Tags.error.length > 0 && !sidebar.collapsed; text: Tags.error; color: sidebar.colors.muted; wrapMode: Text.Wrap; font.pixelSize: 11 }
    }
    Menu {
        id: tagMenu
        width: 210; padding: 6
        popupType: Popup.Window
        background: Loader { source: "../entry/surface.qml"; onLoaded: { item.frosted = true; item.cornerRadius = 12; item.sourceBackdrop = sidebar.Window.window ? sidebar.Window.window.entryBackdrop : null; } }
        component Action: MenuItem {
            id: action
            implicitHeight: 34
            leftPadding: 10; rightPadding: 10
            contentItem: Text { text: action.text; color: sidebar.colors.ink; font.pixelSize: 13; verticalAlignment: Text.AlignVCenter }
            background: Rectangle { radius: 7; color: action.highlighted ? sidebar.colors.selected : "transparent" }
        }
        Action { text: qsTranslate("Pedro", "tags.rename"); onTriggered: sidebar.editingTag = sidebar.contextTag }
        Action { text: qsTranslate("Pedro", "tags.color"); onTriggered: sidebar.colorTag = sidebar.contextTag }
        Action { text: qsTranslate("Pedro", "tags.remove"); enabled: !Tags.busy; onTriggered: { const id = sidebar.contextTag; if (sidebar.editingTag === id) sidebar.editingTag = ""; if (sidebar.colorTag === id) sidebar.colorTag = ""; Qt.callLater(() => Tags.remove(id)); } }
    }
}
