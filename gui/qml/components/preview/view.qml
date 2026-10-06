pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import "../../scripts/theme.js" as Theme

Item {
    id: view
    objectName: "previewView"
    readonly property var controller: view
    property var preview: Backend.preview
    readonly property bool media: preview.kind === "video" || preview.kind === "audio"
    readonly property bool visual: preview.kind === "image" || preview.kind === "document" || preview.kind === "video"
    readonly property color ink: Backend.appearanceMode === "light" ? "#10164d" : "#eef3ff"
    readonly property bool editing: preview.kind === "text" && preview.editable && !preview.busy
    property bool synchronizing: false
    property bool saving: false
    property string loadedText: ""
    property string providerText: ""
    readonly property bool dirty: preview.kind === "text" && editor.text !== loadedText
    property bool discardApproved: false

    function requestClose() {
        if (dirty && !discardApproved && !save()) {
            discardDialog.open();
            return false;
        }
        return true;
    }

    function syncText() {
        synchronizing = true;
        providerText = preview.text;
        editor.text = preview.text;
        loadedText = editor.text;
        synchronizing = false;
    }

    function save() {
        const changed = editor.text !== loadedText;
        if (!editing || !changed || synchronizing || saving) return !changed;
        saving = true;
        const saved = preview.saveText(editor.text);
        if (saved) {
            loadedText = editor.text;
            providerText = preview.text;
        }
        saving = false;
        return saved;
    }

    property real zoom: 1
    property int rotationAngle: 0
    property bool mirrored: false

    function resetImage() {
        zoom = 1;
        rotationAngle = 0;
        mirrored = false;
        canvas.contentX = 0;
        canvas.contentY = 0;
    }

    function close() {
        view.Window.window.close();
    }

    function clock(milliseconds) {
        const seconds = Math.floor(milliseconds / 1000);
        return Math.floor(seconds / 60) + ":" + (seconds % 60).toString().padStart(2, "0");
    }

    Connections {
        target: view.preview
        function onRelocated(source, destination) {
            view.lastSource = view.preview.source.toString();
            const expected = view.lastSource;
            Qt.callLater(() => {
                if (view.preview.source.toString() === expected && view.dirty) view.save();
            });
        }
        function onFileChanged() {
            if (!view.dirty && !view.saving) view.preview.reload();
        }
        function onChanged() {
            const sourceChanged = view.lastSource !== view.preview.source.toString();
            if (sourceChanged) {
                view.lastSource = view.preview.source.toString();
                view.resetImage();
                view.discardApproved = false;
            }
            if (!view.saving && (sourceChanged || view.providerText !== view.preview.text)) view.syncText();
        }
    }
    property string lastSource: ""

    Shortcut { sequence: "Escape"; onActivated: view.close() }
    Shortcut { sequence: "Space"; enabled: view.preview.kind !== "text"; onActivated: view.close() }
    Shortcut { sequence: "K"; enabled: view.media; onActivated: view.preview.togglePlayback() }
    Shortcut { sequence: "PgUp"; enabled: view.preview.page > 0; onActivated: view.preview.setPage(view.preview.page - 1) }
    Shortcut { sequence: "PgDown"; enabled: view.preview.page + 1 < view.preview.pageCount; onActivated: view.preview.setPage(view.preview.page + 1) }
    Shortcut { sequence: "Ctrl+0"; onActivated: view.zoom = 1 }

    Shortcut { sequence: "Ctrl+S"; enabled: view.editing; onActivated: view.save() }

    Controls.Dialog {
        id: discardDialog
        width: Math.min(420, view.width - 32)
        anchors.centerIn: parent
        modal: true
        title: qsTranslate("Pedro", "preview.edit.unsaved")
        standardButtons: Controls.Dialog.Discard | Controls.Dialog.Cancel
        onDiscarded: { view.discardApproved = true; view.close(); }
        contentItem: Controls.Label { text: qsTranslate("Pedro", "preview.edit.discard"); color: view.ink }
    }

    DropArea {
        enabled: !view.editing
        anchors.fill: parent
        onEntered: drag => { drag.accepted = drag.hasUrls; }
        onDropped: drop => {
            if (drop.hasUrls && drop.urls.length) {
                view.preview.open(drop.urls[0], drop.urls);
                drop.acceptProposedAction();
            }
        }
    }

    component Button: Controls.Button {
        id: control
        padding: 8
        contentItem: Controls.Label {
            text: control.text
            color: view.ink
            opacity: control.enabled ? 1 : 0.35
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: 7
            color: control.down ? Theme.controlPressed : control.hovered ? Theme.controlHover : "transparent"
        }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
    }

    Rectangle {
        id: photoMask
        width: stage.width
        height: stage.height
        radius: 12
        color: "white"
        visible: false
        layer.enabled: true
        layer.smooth: true
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        RowLayout {
            objectName: "previewToolbar"
            visible: view.preview.kind !== "image" && view.preview.kind !== "video" && view.preview.kind !== "text"
            Layout.fillWidth: true
            Controls.Label {
                Layout.fillWidth: true
                text: view.preview.kind.length ? qsTranslate("Pedro", "preview.type." + view.preview.kind) : ""
                color: view.ink
                opacity: 0.65
                elide: Text.ElideRight
                font.pixelSize: 12
            }
            Button { text: "−"; visible: view.visual && !view.media; Accessible.name: qsTranslate("Pedro", "preview.zoom.out"); onClicked: view.zoom = Math.max(0.25, view.zoom / 1.25) }
            Button { text: Math.round(view.zoom * 100) + "%"; visible: view.visual && !view.media; Accessible.name: qsTranslate("Pedro", "preview.fit"); onClicked: view.zoom = 1 }
            Button { text: "+"; visible: view.visual && !view.media; Accessible.name: qsTranslate("Pedro", "preview.zoom.in"); onClicked: view.zoom = Math.min(8, view.zoom * 1.25) }
            Button { text: qsTranslate("Pedro", "preview.rotate"); visible: view.preview.kind === "image"; onClicked: view.rotationAngle = (view.rotationAngle + 90) % 360 }
        }

        Rectangle {
            id: stage
            Layout.fillWidth: true
            Layout.fillHeight: true
            layer.enabled: view.preview.kind === "image" || view.preview.kind === "video"
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: photoMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 0.5
                autoPaddingEnabled: false
            }
            color: view.preview.kind === "video" ? "#080b10" : Backend.appearanceMode === "light" ? "#20ffffff" : "#20000000"
            radius: 12
            clip: true

            Flickable {
                id: canvas
                anchors.fill: parent
                visible: view.visual && !view.preview.error.length
                contentWidth: Math.max(width, surface.turned ? surface.height : surface.width)
                contentHeight: Math.max(height, surface.turned ? surface.width : surface.height)
                boundsBehavior: Flickable.StopAtBounds
                onWidthChanged: returnToBounds()
                onHeightChanged: returnToBounds()
                Image {
                    id: surface
                    objectName: "previewSurface"
                    readonly property bool turned: view.rotationAngle % 180 !== 0
                    readonly property real naturalWidth: turned ? view.preview.frameSize.height : view.preview.frameSize.width
                    readonly property real naturalHeight: turned ? view.preview.frameSize.width : view.preview.frameSize.height
                    readonly property real fit: naturalWidth > 0 && naturalHeight > 0 ? Math.min(canvas.width / naturalWidth, canvas.height / naturalHeight) : 1
                    width: view.preview.frameSize.width * fit * view.zoom
                    height: view.preview.frameSize.height * fit * view.zoom
                    x: (canvas.contentWidth - width) / 2
                    y: (canvas.contentHeight - height) / 2
                    source: view.preview.frameSize.width > 0 ? "image://preview/" + (view.preview.objectName.length ? view.preview.objectName + "/" : "") + "frame/" + view.preview.revision : ""
                    cache: false
                    fillMode: Image.PreserveAspectFit
                    rotation: view.rotationAngle
                    transform: Scale { origin.x: surface.width / 2; origin.y: surface.height / 2; xScale: view.mirrored ? -1 : 1 }
                    smooth: true
                    mipmap: !view.media
                }
                Controls.ScrollBar.horizontal: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded; visible: size < 1 }
                Controls.ScrollBar.vertical: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded; visible: size < 1 }
            }

            Controls.ScrollView {
                Controls.ScrollBar.vertical.policy: Controls.ScrollBar.AsNeeded
                Controls.ScrollBar.vertical.visible: Controls.ScrollBar.vertical.size < 1
                Controls.ScrollBar.horizontal.policy: Controls.ScrollBar.AsNeeded
                Controls.ScrollBar.horizontal.visible: Controls.ScrollBar.horizontal.size < 1
                anchors.fill: parent
                anchors.margins: 16
                visible: view.preview.kind === "text" && !view.preview.error.length
                Controls.TextArea {
                    id: editor
                    objectName: "previewText"
                    text: ""
                    Component.onCompleted: view.syncText()
                    onTextChanged: { if (!view.synchronizing) view.save(); }
                    textFormat: TextEdit.PlainText
                    readOnly: !view.editing
                    focus: view.editing
                    selectByMouse: true
                    wrapMode: TextEdit.NoWrap
                    color: view.ink
                    font.family: "monospace"
                    font.pixelSize: 14
                    background: null
                }
            }

            Column {
                anchors.centerIn: parent
                width: parent.width - 48
                spacing: 12
                visible: view.preview.kind === "audio" || view.preview.error.length > 0
                Controls.Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: view.preview.error.length ? qsTranslate("Pedro", "preview.unavailable") : "♫"
                    color: view.ink
                    font.pixelSize: view.preview.error.length ? 20 : 64
                }
                Controls.Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: view.preview.error.length ? view.preview.error : view.preview.name
                    color: view.ink
                }
            }
            Loader {
                anchors.fill: parent
                active: view.preview.kind === "video"
                source: "video.qml"
                onLoaded: {
                    item.controller = view;
                    item.backdrop = surface;
                }
            }

            Controls.BusyIndicator {
                anchors.centerIn: parent
                running: view.preview.busy
                visible: running
            }
        }

        Controls.Label {
            Layout.fillWidth: true
            visible: view.preview.saveError.length > 0 || view.dirty
            text: view.preview.saveError.length ? view.preview.saveError : qsTranslate("Pedro", "preview.edit.unsaved")
            color: view.ink
            wrapMode: Text.Wrap
        }

        Controls.Label {
            visible: view.preview.kind === "text" && view.preview.textTruncated
            text: qsTranslate("Pedro", "preview.text.limited")
            color: view.ink
            opacity: 0.65
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            visible: view.preview.kind === "document" && view.preview.pageCount > 0
            Button { text: "‹"; enabled: !view.preview.busy && view.preview.page > 0; Accessible.name: qsTranslate("Pedro", "preview.page.previous"); onClicked: view.preview.setPage(view.preview.page - 1) }
            Controls.Label { text: (view.preview.page + 1) + " / " + view.preview.pageCount; color: view.ink }
            Button { text: "›"; enabled: !view.preview.busy && view.preview.page + 1 < view.preview.pageCount; Accessible.name: qsTranslate("Pedro", "preview.page.next"); onClicked: view.preview.setPage(view.preview.page + 1) }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: view.preview.kind === "audio"
            Button { text: view.preview.playing ? qsTranslate("Pedro", "preview.pause") : qsTranslate("Pedro", "preview.play"); enabled: !view.preview.error.length; onClicked: view.preview.togglePlayback() }
            Controls.Label { text: view.clock(view.preview.position); color: view.ink }
            Controls.Slider {
                Layout.fillWidth: true
                from: 0
                to: Math.max(1, view.preview.duration)
                value: view.preview.position
                enabled: view.preview.seekable
                onMoved: view.preview.seek(value)
                Accessible.name: qsTranslate("Pedro", "preview.position")
            }
            Controls.Label { text: view.clock(view.preview.duration); color: view.ink }
            Button { text: view.preview.muted ? qsTranslate("Pedro", "preview.unmute") : qsTranslate("Pedro", "preview.mute"); onClicked: view.preview.muted = !view.preview.muted }
            Controls.Slider {
                Layout.preferredWidth: 90
                from: 0
                to: 1
                value: view.preview.volume
                onMoved: view.preview.volume = value
                Accessible.name: qsTranslate("Pedro", "preview.volume")
            }
        }
    }
}
