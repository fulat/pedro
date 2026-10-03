pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import ".." as Components
import "../icon" as Icon
import "../../scripts/theme.js" as Theme

Item {
    id: root
    property var capture: Backend.capture
    property Item backdrop
    property point screenOrigin
    property rect region: Qt.rect(width * 0.25, height * 0.25, width * 0.5, height * 0.5)
    property bool area: true
    property bool video: false
    property bool cursor: false
    property int delay: 0

    visible: capture.visible
    focus: capture.visible
    Keys.onEscapePressed: capture.close()

    function submit() {
        const selected = area ? region : Qt.rect(0, 0, width, height);
        capture.take(Qt.rect(Math.round(screenOrigin.x + selected.x), Math.round(screenOrigin.y + selected.y), Math.round(selected.width), Math.round(selected.height)), video, cursor, delay);
    }

    MouseArea {
        anchors.fill: parent
        visible: root.capture.visible
        cursorShape: root.area ? Qt.CrossCursor : Qt.ArrowCursor
        property point start
        onPressed: mouse => { start = Qt.point(mouse.x, mouse.y); }
        onPositionChanged: mouse => {
            if (pressed && root.area) {
                const x = Math.max(0, Math.min(start.x, mouse.x));
                const y = Math.max(0, Math.min(start.y, mouse.y));
                root.region = Qt.rect(x, y, Math.max(24, Math.min(root.width, Math.max(start.x, mouse.x)) - x), Math.max(24, Math.min(root.height, Math.max(start.y, mouse.y)) - y));
            }
        }
    }

    Item {
        id: selection
        visible: root.capture.visible && root.area
        x: root.region.x
        y: root.region.y
        width: root.region.width
        height: root.region.height

        Rectangle { x: -selection.x; y: -selection.y; width: root.width; height: selection.y; color: "#44000000" }
        Rectangle { x: -selection.x; y: selection.height; width: root.width; height: root.height - selection.y - selection.height; color: "#44000000" }
        Rectangle { x: -selection.x; width: selection.x; height: selection.height; color: "#44000000" }
        Rectangle { x: selection.width; width: root.width - selection.x - selection.width; height: selection.height; color: "#44000000" }
        Repeater {
            model: Math.floor(selection.width / 10)
            delegate: Item {
                required property int index
                x: index * 10
                Rectangle { width: 5; height: 1; color: Theme.white }
                Rectangle { y: selection.height; width: 5; height: 1; color: Theme.white }
            }
        }
        Repeater {
            model: Math.floor(selection.height / 10)
            delegate: Item {
                required property int index
                y: index * 10
                Rectangle { width: 1; height: 5; color: Theme.white }
                Rectangle { x: selection.width; width: 1; height: 5; color: Theme.white }
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.SizeAllCursor
            property point start
            property rect original
            onPressed: mouse => { start = mapToItem(root, mouse.x, mouse.y); original = root.region; }
            onPositionChanged: mouse => {
                if (pressed) {
                    const point = mapToItem(root, mouse.x, mouse.y);
                    root.region = Qt.rect(Math.max(0, Math.min(root.width - original.width, original.x + point.x - start.x)), Math.max(0, Math.min(root.height - original.height, original.y + point.y - start.y)), original.width, original.height);
                }
            }
        }
        Repeater {
            model: 4
            delegate: Rectangle {
                id: handle
                required property int index
                x: index % 2 ? selection.width - 4 : -4
                y: index > 1 ? selection.height - 4 : -4
                width: 8; height: 8; radius: 4
                color: Theme.white
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: handle.index === 0 || handle.index === 3 ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor
                    property rect original
                    onPressed: original = root.region
                    onPositionChanged: mouse => {
                        if (!pressed) return;
                        const point = mapToItem(root, mouse.x, mouse.y);
                        const left = handle.index % 2 ? original.x : Math.max(0, Math.min(original.x + original.width - 24, point.x));
                        const top = handle.index > 1 ? original.y : Math.max(0, Math.min(original.y + original.height - 24, point.y));
                        const right = handle.index % 2 ? Math.min(root.width, Math.max(original.x + 24, point.x)) : original.x + original.width;
                        const bottom = handle.index > 1 ? Math.min(root.height, Math.max(original.y + 24, point.y)) : original.y + original.height;
                        root.region = Qt.rect(left, top, right - left, bottom - top);
                    }
                }
            }
        }
    }

    Rectangle {
        id: toolbar
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 28
        width: Math.min(root.width - 24, controls.implicitWidth + 24)
        height: controls.implicitHeight + 20
        radius: 20
        color: "transparent"
        Components.Liquid { anchors.fill: parent; backdrop: root.backdrop; frosted: true; cornerRadius: 20 }
        Rectangle { anchors.fill: parent; radius: 20; color: Theme.menuBackground; opacity: 0.55 }
        RowLayout {
            id: controls
            anchors.centerIn: parent
            spacing: 6
            Action {
                visible: !root.capture.recording
                text: "×"
                onClicked: root.capture.close()
            }
            Action {
                visible: !root.capture.recording
                text: qsTranslate("Pedro", "capture.screen")
                checkable: true; checked: !root.area
                onClicked: root.area = false
            }
            Action {
                visible: !root.capture.recording
                text: qsTranslate("Pedro", "capture.area")
                checkable: true; checked: root.area
                onClicked: root.area = true
            }
            Rectangle { visible: !root.capture.recording; Layout.preferredWidth: 1; Layout.preferredHeight: 22; color: Theme.dividerSoft }
            Action {
                visible: !root.capture.recording
                text: root.video ? qsTranslate("Pedro", "capture.video") : qsTranslate("Pedro", "capture.image")
                onClicked: root.video = !root.video
            }
            Action {
                visible: !root.capture.recording
                text: qsTranslate("Pedro", "capture.options")
                onClicked: options.open()
                Menu {
                    id: options
                    y: -height - 8
                    background: Rectangle {
                        implicitWidth: 190
                        radius: 14
                        color: Theme.menuBackground
                        border.color: Theme.cardBorder
                    }
                    MenuItem { palette.text: Theme.white; text: qsTranslate("Pedro", "capture.cursor"); checkable: true; checked: root.cursor; onTriggered: root.cursor = !root.cursor }
                    MenuSeparator {}
                    Repeater {
                        model: [0, 3, 5]
                        delegate: MenuItem {
                            palette.text: Theme.white
                            required property int modelData
                            text: modelData === 0 ? qsTranslate("Pedro", "capture.noDelay") : modelData + " s"
                            checkable: true; checked: root.delay === modelData
                            onTriggered: root.delay = modelData
                        }
                    }
                }
            }
            Action {
                text: root.capture.recording ? qsTranslate("Pedro", "capture.stop") : root.video ? qsTranslate("Pedro", "capture.record") : qsTranslate("Pedro", "capture.take")
                enabled: !root.capture.busy
                onClicked: root.capture.recording ? root.capture.stop() : root.submit()
                background: Rectangle { implicitWidth: Math.max(72, parent.contentItem.implicitWidth + 20); implicitHeight: 36; radius: 12; color: root.capture.recording ? Theme.notificationMuted : Theme.overlayPressed }
            }
        }
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: toolbar.top
        anchors.bottomMargin: 14
        width: Math.min(root.width - 32, 540)
        text: root.capture.error
        color: Theme.white
        font.pixelSize: 13
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
    }

    component Action: Button {
        id: action
        contentItem: Text {
            text: action.text
            color: Theme.white
            font.pixelSize: 12
            font.weight: Font.Medium
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            implicitWidth: Math.max(34, action.contentItem.implicitWidth + 20)
            implicitHeight: 36
            radius: 12
            color: action.down || action.checked ? Theme.overlayPressed : action.hovered ? Theme.overlayHover : "transparent"
        }
        HoverHandler { cursorShape: action.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor }
    }
}
