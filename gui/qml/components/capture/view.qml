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
    property var quickWindows: []
    property var windowProvider: null
    property var selectedWindow: null
    property bool windowMode: false
    property bool area: true
    property bool video: false
    property bool cursor: false
    property int delay: 0
    property bool microphone: false

    visible: capture.visible
    focus: capture.visible
    Keys.onEscapePressed: capture.close()

    function submit() {
        if (windowMode && (!selectedWindow || !selectedWindow.visible)) {
            windows.open();
            return;
        }
        const selected = windowMode ? Qt.rect(selectedWindow.x, selectedWindow.y, selectedWindow.width, selectedWindow.height) : area ? Qt.rect(screenOrigin.x + region.x, screenOrigin.y + region.y, region.width, region.height) : screenGeometry;
        capture.take(Qt.rect(Math.round(selected.x), Math.round(selected.y), Math.round(selected.width), Math.round(selected.height)), video, cursor, delay);
    }

    MouseArea {
        anchors.fill: parent
        visible: root.capture.visible
        cursorShape: root.area && !root.windowMode ? Qt.CrossCursor : Qt.ArrowCursor
        property point start
        onPressed: mouse => { start = Qt.point(mouse.x, mouse.y); }
        onPositionChanged: mouse => {
            if (pressed && root.area && !root.windowMode) {
                const x = Math.max(0, Math.min(start.x, mouse.x));
                const y = Math.max(0, Math.min(start.y, mouse.y));
                root.region = Qt.rect(x, y, Math.max(24, Math.min(root.width, Math.max(start.x, mouse.x)) - x), Math.max(24, Math.min(root.height, Math.max(start.y, mouse.y)) - y));
            }
        }
    }

    Item {
        id: selection
        visible: root.capture.visible && root.area && !root.windowMode
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
                    objectName: "captureImage"
                    text: qsTranslate("Pedro", "capture.image")
                    symbol: "../../../assets/icons/capture/camera.svg"
                    showText: true
                    stacked: true
                    checked: !root.video
                    onClicked: root.video = false
                }
                Action {
                    objectName: "captureVideo"
                    text: qsTranslate("Pedro", "capture.video")
                    symbol: "../../../assets/icons/capture/video.svg"
                    showText: true
                    stacked: true
                    checked: root.video
                    onClicked: root.video = true
                }
                Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 22; color: Theme.dividerSoft }
                Action {
                    objectName: "captureScreen"
                    text: qsTranslate("Pedro", "capture.screen")
                    symbol: "../../../assets/icons/capture/screen.svg"
                    showText: true
                    stacked: true
                    checked: !root.area && !root.windowMode
                    onClicked: { root.windowMode = false; root.area = false; }
                }
                Action {
                    objectName: "captureArea"
                    text: qsTranslate("Pedro", "capture.area")
                    symbol: "../../../assets/icons/selection.svg"
                    showText: true
                    stacked: true
                    checked: root.area && !root.windowMode
                    onClicked: { root.windowMode = false; root.area = true; }
                }
                Action {
                    objectName: "captureWindow"
                    text: qsTranslate("Pedro", "capture.window")
                    symbol: "../../../assets/icons/capture/window.svg"
                    showText: true
                    stacked: true
                    checked: root.windowMode
                    onClicked: {
                        if (root.windowProvider) root.quickWindows = root.windowProvider();
                        windows.open();
                    }
                    GlassMenu {
                        id: windows
                        objectName: "captureWindows"
                        y: -height - 8
                        Heading { text: qsTranslate("Pedro", "capture.chooseWindow") }
                        Heading { visible: root.quickWindows.length === 0; text: qsTranslate("Pedro", "capture.noWindows") }
                        Repeater {
                            model: root.quickWindows
                            delegate: Option {
                                required property var modelData
                                text: modelData.controller && modelData.controller.directory && modelData.controller.directory.path
                                    ? modelData.controller.directory.path.split("/").filter(part => part.length).pop() || modelData.title
                                    : modelData.title
                                checkable: true
                                checked: root.windowMode && root.selectedWindow === modelData
                                onChosen: {
                                    root.selectedWindow = modelData;
                                    root.windowMode = true;
                                    windows.close();
                                }
                            }
                        }
                    }
                }
                Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 22; color: Theme.dividerSoft }
                Action {
                    text: qsTranslate("Pedro", "capture.options")
                    symbol: "../../../assets/icons/capture/options.svg"
                    showText: true
                    stacked: true
                    onClicked: options.open()
                    GlassMenu {
                        id: options
                        objectName: "captureOptions"
                        y: -height - 8
                        Heading { text: qsTranslate("Pedro", "capture.timer") }
                        Repeater {
                            model: [0, 3, 5, 10]
                            delegate: Option {
                                required property int modelData
                                objectName: "captureTimer" + modelData
                                text: modelData === 0 ? qsTranslate("Pedro", "capture.noDelay") : modelData + " s"
                                checkable: true
                                checked: root.delay === modelData
                                onChosen: root.delay = modelData
                            }
                        }
                        Divider {}
                        Heading { text: qsTranslate("Pedro", "capture.pointer") }
                        Option {
                            text: qsTranslate("Pedro", "capture.cursor")
                            checkable: true
                            checked: root.cursor
                            onChosen: root.cursor = !root.cursor
                        }
                        Divider {}
                        Heading { text: qsTranslate("Pedro", "capture.audio") }
                        GlassMenu {
                            objectName: "captureMicrophones"
                            title: qsTranslate("Pedro", "capture.microphones")
                            width: 250
                            padding: 6
                            popupType: Popup.Item
                            background: Components.Liquid { backdrop: root.backdrop; frosted: true; cornerRadius: 12 }
                            delegate: Option {}
                            Heading { text: qsTranslate("Pedro", "capture.preview") }
                            Option { text: qsTranslate("Pedro", "capture.none"); checkable: true; checked: !root.microphone; onChosen: root.microphone = false }
                            Option { microphoneIcon: true; text: qsTranslate("Pedro", "capture.defaultMicrophone"); checkable: true; checked: root.microphone; onChosen: root.microphone = true }
                            Divider {}
                            Heading { text: qsTranslate("Pedro", "capture.microphoneNote") }
                        }
                    }
                }
                Action {
                    text: root.video ? qsTranslate("Pedro", "capture.record") : qsTranslate("Pedro", "capture.take")
                    symbol: root.video ? "../../../assets/icons/capture/record.svg" : "../../../assets/icons/capture/camera.svg"
                    accent: true
                    circular: true
                    Layout.preferredWidth: 42
                    Layout.preferredHeight: 42
                    enabled: !root.capture.busy && (!root.windowMode || (root.selectedWindow && root.selectedWindow.visible))
                    onClicked: root.submit()
                }
                Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 30; color: Theme.dividerSoft }
                Action {
                    text: qsTranslate("Pedro", "capture.close")
                    symbol: "../../../assets/icons/capture/close.svg"
                    circular: true
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

    component GlassMenu: Menu {
        width: 250
        padding: 6
        popupType: Popup.Item
        cascade: true
        delegate: Option {}
        background: Components.Liquid { backdrop: root.backdrop; frosted: true; blurAmount: 1.0; cornerRadius: 12 }
    }

    component Heading: MenuItem {
        id: heading
        enabled: false
        implicitHeight: 32
        leftPadding: 12
        topPadding: 8
        contentItem: Text { text: heading.text; color: Theme.textMuted; font.pixelSize: 12; font.weight: Font.DemiBold; wrapMode: Text.WordWrap }
        background: Item {}
    }

    component Divider: MenuSeparator {
        topPadding: 6
        bottomPadding: 6
        contentItem: Rectangle { implicitHeight: 1; color: Theme.dividerBright }
    }

    component Option: MenuItem {
        id: option
        property bool microphoneIcon: false
        objectName: subMenu ? "captureMicrophonesEntry" : ""
        signal chosen()
        hoverEnabled: true
        Keys.onSpacePressed: event => { if (!subMenu) { chosen(); event.accepted = true; } }
        Keys.onReturnPressed: event => { if (!subMenu) { chosen(); event.accepted = true; } }
        MouseArea {
            id: optionMouse
            anchors.fill: parent
            enabled: !option.subMenu
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: option.chosen()
        }
        implicitHeight: 34
        leftPadding: 12
        rightPadding: 12
        indicator: Item {}
        arrow: Item {}
        contentItem: Item {
            Text { anchors.left: parent.left; anchors.leftMargin: option.microphoneIcon || option.subMenu ? 27 : 0; anchors.verticalCenter: parent.verticalCenter; text: option.text; color: Theme.white; font.pixelSize: 13 }
            Icon.Tinted {
                visible: option.microphoneIcon || !!option.subMenu
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 18; height: 18
                source: "../../../assets/icons/capture/microphone.svg"
            }
            Text {
                visible: !!option.subMenu
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "›"
                font.pixelSize: 22
                color: Theme.textMuted
            }
            Rectangle {
                visible: option.checkable
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 16; height: 16; radius: 8
                color: option.checked ? Theme.overlayHover : "transparent"
                border.width: 1
                border.color: option.checked ? Theme.textMuted : Theme.cardBorderStrong
                Rectangle { anchors.centerIn: parent; width: 6; height: 6; radius: 3; visible: option.checked; color: Theme.textMuted }
            }
        }
        background: Rectangle { radius: 6; color: optionMouse.containsMouse || option.hovered || option.highlighted ? "#18ffffff" : "transparent" }
    }

    component Action: Button {
        id: action
        property url symbol
        property bool showText: false
        property bool accent: false
        property bool stacked: false
        property bool circular: false
        hoverEnabled: true
        Accessible.name: text
        contentItem: Item {
            implicitWidth: action.stacked ? Math.max(label.implicitWidth, 64) : (action.symbol.toString().length > 0 ? 25 : 0) + (action.showText ? label.implicitWidth : 0)
            implicitHeight: action.stacked ? 38 : 20
            Icon.Tinted {
                id: symbol
                visible: action.symbol.toString().length > 0
                source: action.symbol
                width: action.accent ? 22 : 19
                height: action.accent ? 22 : 19
                x: action.stacked || action.circular ? (parent.width - width) / 2 : 0
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
            radius: action.circular ? height / 2 : action.accent ? 12 : 11
            border.width: action.accent || action.circular ? 1 : 0
            border.color: action.accent ? (action.hovered ? "#88ffffff" : "#55ffffff") : Theme.cardBorderStrong
            color: action.down ? "#32ffffff" : action.hovered ? "#26ffffff" : action.accent ? "#24ffffff" : action.checked ? "#18ffffff" : action.circular ? "#0cffffff" : "transparent"
            Behavior on color { ColorAnimation { duration: 100 } }
        }
        ToolTip.visible: hovered && !showText
        ToolTip.delay: 400
        ToolTip.text: text
        HoverHandler { cursorShape: action.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor }
    }
}
