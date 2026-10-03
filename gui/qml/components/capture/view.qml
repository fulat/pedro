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
    property rect screenGeometry: Qt.rect(Screen.virtualX, Screen.virtualY, Screen.width, Screen.height)
    property rect region: Qt.rect(width * 0.25, height * 0.25, width * 0.5, height * 0.5)
    property bool area: true
    property bool video: false
    property bool cursor: false
    property int delay: 0

    visible: capture.visible
    focus: capture.visible
    Keys.onEscapePressed: capture.close()

    function submit() {
        const selected = area ? Qt.rect(screenOrigin.x + region.x, screenOrigin.y + region.y, region.width, region.height) : screenGeometry;
        capture.take(Qt.rect(Math.round(selected.x), Math.round(selected.y), Math.round(selected.width), Math.round(selected.height)), video, cursor, delay);
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
            model: 8
            delegate: Rectangle {
                id: handle
                required property int index
                readonly property bool leftEdge: index === 0 || index === 2 || index === 4
                readonly property bool rightEdge: index === 1 || index === 3 || index === 5
                readonly property bool topEdge: index === 0 || index === 1 || index === 6
                readonly property bool bottomEdge: index === 2 || index === 3 || index === 7
                x: leftEdge ? -4 : rightEdge ? selection.width - 4 : selection.width / 2 - 4
                y: topEdge ? -4 : bottomEdge ? selection.height - 4 : selection.height / 2 - 4
                width: 8
                height: 8
                radius: 4
                color: Theme.white
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: handle.index >= 6 ? Qt.SizeVerCursor : handle.index >= 4 ? Qt.SizeHorCursor : handle.index === 0 || handle.index === 3 ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor
                    property rect original
                    property point start
                    onPressed: mouse => {
                        original = root.region;
                        start = mapToItem(root, mouse.x, mouse.y);
                    }
                    onPositionChanged: mouse => {
                        if (!pressed) {
                            return;
                        }
                        const point = mapToItem(root, mouse.x, mouse.y);
                        const dx = point.x - start.x;
                        const dy = point.y - start.y;
                        const left = handle.leftEdge ? Math.max(0, Math.min(original.x + original.width - 24, original.x + dx)) : original.x;
                        const top = handle.topEdge ? Math.max(0, Math.min(original.y + original.height - 24, original.y + dy)) : original.y;
                        const right = handle.rightEdge ? Math.min(root.width, Math.max(original.x + 24, original.x + original.width + dx)) : original.x + original.width;
                        const bottom = handle.bottomEdge ? Math.min(root.height, Math.max(original.y + 24, original.y + original.height + dy)) : original.y + original.height;
                        root.region = Qt.rect(left, top, right - left, bottom - top);
                    }
                }
            }
        }
    }

    Rectangle {
        id: toolbar
        objectName: "captureToolbar"
        x: (root.width - width) / 2
        y: root.height - height - 28
        width: Math.min(root.width - 24, controls.implicitWidth + 48)
        height: 62
        radius: 28
        color: "transparent"
        Components.Liquid { anchors.fill: parent; backdrop: root.backdrop; frosted: true; cornerRadius: 28 }
        Rectangle { anchors.fill: parent; radius: 28; color: Theme.menuBackground; opacity: 0.55 }

        RowLayout {
                id: controls
                anchors.centerIn: parent
                spacing: 7
                Item {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 46
                    Repeater {
                        model: 6
                        delegate: Rectangle {
                            required property int index
                            x: 9 + index % 2 * 7
                            y: 14 + Math.floor(index / 2) * 7
                            width: 3
                            height: 3
                            radius: 1.5
                            color: Theme.textMuted
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.SizeAllCursor
                        drag.target: toolbar
                        drag.minimumX: 12
                        drag.maximumX: Math.max(12, root.width - toolbar.width - 12)
                        drag.minimumY: 12
                        drag.maximumY: Math.max(12, root.height - toolbar.height - 12)
                    }
                }
                Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 30; color: Theme.dividerSoft }
                Action {
                    text: qsTranslate("Pedro", "capture.screen")
                    symbol: "../../../assets/icons/display.svg"
                    showText: true
                    stacked: true
                    checkable: true; checked: !root.area
                    onClicked: root.area = false
                }
                Action {
                    text: qsTranslate("Pedro", "capture.area")
                    symbol: "../../../assets/icons/selection.svg"
                    showText: true
                    stacked: true
                    checkable: true; checked: root.area
                    onClicked: root.area = true
                }
                Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 22; color: Theme.dividerSoft }
                Action {
                    text: qsTranslate("Pedro", "capture.image")
                    symbol: "../../../assets/icons/image.svg"
                    showText: true
                    stacked: true
                    checkable: true; checked: !root.video
                    onClicked: root.video = false
                }
                Action {
                    text: qsTranslate("Pedro", "capture.video")
                    symbol: "../../../assets/icons/video.svg"
                    showText: true
                    stacked: true
                    checkable: true; checked: root.video
                    onClicked: root.video = true
                }
                Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 22; color: Theme.dividerSoft }
                Action {
                    text: qsTranslate("Pedro", "capture.options")
                    symbol: "../../../assets/icons/settings.svg"
                    showText: true
                    stacked: true
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
                    text: root.video ? qsTranslate("Pedro", "capture.record") : qsTranslate("Pedro", "capture.take")
                    symbol: root.video ? "../../../assets/icons/video.svg" : "../../../assets/icons/image.svg"
                    showText: true
                    accent: true
                    Layout.preferredWidth: 132
                    enabled: !root.capture.busy
                    onClicked: root.submit()
                }
                Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 30; color: Theme.dividerSoft }
                Action {
                    text: "×"
                    showText: true
                    Layout.preferredWidth: 36
                    onClicked: root.capture.close()
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
        property url symbol
        property bool showText: false
        property bool accent: false
        property bool stacked: false
        Accessible.name: text
        contentItem: Item {
            implicitWidth: action.stacked ? Math.max(label.implicitWidth, 64) : (action.symbol.toString().length > 0 ? 25 : 0) + (action.showText ? label.implicitWidth : 0)
            implicitHeight: action.stacked ? 38 : 20
            Icon.Tinted {
                id: symbol
                visible: action.symbol.toString().length > 0
                source: action.symbol
                width: 19
                height: 19
                x: action.stacked ? (parent.width - width) / 2 : 0
                y: action.stacked ? 0 : (parent.height - height) / 2
            }
            Text {
                id: label
                visible: action.showText
                text: action.text
                color: Theme.white
                font.pixelSize: 12
                font.weight: Font.Medium
                x: action.stacked ? (parent.width - width) / 2 : symbol.visible ? 26 : (parent.width - width) / 2
                y: action.stacked ? 23 : (parent.height - height) / 2
            }
        }
        background: Rectangle {
            implicitWidth: action.stacked ? action.contentItem.implicitWidth + 16 : action.showText ? action.contentItem.implicitWidth + 22 : 36
            implicitHeight: action.stacked ? 46 : 36
            radius: 11
            border.width: action.accent ? 1 : 0
            border.color: Theme.cardBorderStrong
            color: action.down || action.checked ? Theme.overlayPressed : action.hovered || action.accent ? Theme.overlayHover : "transparent"
        }
        ToolTip.visible: hovered && !showText
        ToolTip.delay: 400
        ToolTip.text: text
        HoverHandler { cursorShape: action.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor }
    }
}
