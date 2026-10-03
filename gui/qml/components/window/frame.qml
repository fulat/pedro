pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Window
import QtQuick.Controls.Basic as Controls
import ".." as Components
import "../icon" as Icon
import "../../scripts/theme.js" as Theme

Window {
    id: frame

    readonly property var controller: contentLoader.item ? contentLoader.item.controller || null : null
    readonly property alias entryBackdrop: windowBackdrop
    property url headerSource
    property real headerHeight: 44
    property real titleOffset: 90
    property real titleSize: 13
    property bool titleInteractive: false
    signal titleClicked()
    property real contentMargin: 12
    property real contentTopGap: 6
    readonly property real titleContentWidth: windowTitle.contentWidth
    property real headerOffset: 240
    Behavior on headerOffset {
        NumberAnimation { duration: 240; easing.type: Easing.InOutCubic }
    }
    property real windowRadius: 14
    readonly property alias contentItem: contentLoader.item
    property url contentSource
    property color surfaceColor: "transparent"
    property color surfaceEndColor: surfaceColor
    property bool opaqueSurface: false
    property color titleColor: Theme.white
    readonly property real resizeBorder: 7
    readonly property real resizeCorner: 18
    readonly property bool maximized: visibility === Window.Maximized

    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint | Qt.WindowMinMaxButtonsHint
    visible: false
    width: 760
    height: 520
    minimumWidth: 420
    minimumHeight: 320

    function toggleMaximized() {
        if (maximized) {
            showNormal();
        } else {
            showMaximized();
        }
    }

    Rectangle {
        id: windowMask
        anchors.fill: parent
        radius: frame.maximized ? 0 : frame.windowRadius
        color: "white"
        visible: false
        layer.enabled: true
        layer.smooth: true
        antialiasing: true
    }

    Item {
        anchors.fill: parent
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: windowMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 0.5
            autoPaddingEnabled: false
        }

        Image {
            id: windowBackdrop
            anchors.fill: parent
            source: Backend.wallpaper
            fillMode: Image.PreserveAspectCrop
            visible: false
            smooth: true
            mipmap: true
        }

        Components.Liquid {
            anchors.fill: parent
            visible: !frame.opaqueSurface
            backdrop: windowBackdrop
            frosted: true
            cornerRadius: frame.maximized ? 0 : frame.windowRadius
        }

        Rectangle {
            anchors.fill: parent
            color: frame.surfaceColor
            gradient: frame.opaqueSurface ? surfaceGradient : null
            radius: frame.maximized ? 0 : frame.windowRadius

            Gradient {
                id: surfaceGradient
                GradientStop { position: 0; color: frame.surfaceColor }
                GradientStop { position: 1; color: frame.surfaceEndColor }
            }
        }

        Item {
            id: header
            width: parent.width
            height: frame.headerHeight

            DragHandler {
                target: null
                onActiveChanged: {
                    if (active) {
                        frame.startSystemMove();
                    }
                }
            }
            TapHandler {
                onDoubleTapped: frame.toggleMaximized()
            }

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                Controls.Button {
                    id: closeControl
                    objectName: "windowClose"
                    width: 20
                    height: 28
                    hoverEnabled: true
                    Accessible.name: qsTranslate("Pedro", "common.close")
                    onClicked: frame.close()
                    background: ControlBackground { control: closeControl; tint: "#ff5c5f"; symbol: "close" }
                }
                Controls.Button {
                    id: minimizeControl
                    objectName: "windowMinimize"
                    width: 20
                    height: 28
                    hoverEnabled: true
                    Accessible.name: qsTranslate("Pedro", "window.minimize")
                    onClicked: frame.showMinimized()
                    background: ControlBackground { control: minimizeControl; tint: "#fac800"; symbol: "minimize" }
                }
                Controls.Button {
                    id: maximizeControl
                    objectName: "windowMaximize"
                    width: 20
                    height: 28
                    hoverEnabled: true
                    Accessible.name: frame.maximized ? qsTranslate("Pedro", "window.restore") : qsTranslate("Pedro", "window.maximize")
                    onClicked: frame.toggleMaximized()
                    background: ControlBackground {
                        control: maximizeControl
                        tint: frame.maximized ? "#2396f3" : "#35c759"
                        symbol: frame.maximized ? "restore" : "maximize"
                    }
                }
            }

            Text {
                id: windowTitle
                anchors.left: parent.left
                anchors.leftMargin: frame.titleOffset
                anchors.right: parent.right
                anchors.rightMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                text: frame.title
                color: frame.titleColor
                font.pixelSize: frame.titleSize
                font.weight: frame.titleSize > 13 ? Font.Bold : Font.Medium
                elide: Text.ElideRight
                MouseArea {
                    objectName: "windowTitleToggle"
                    enabled: frame.titleInteractive
                    width: Math.min(parent.width, parent.contentWidth)
                    height: parent.height
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: frame.titleClicked()
                }
            }
        }

        Loader {
            anchors.left: parent.left
            anchors.leftMargin: frame.headerOffset
            anchors.right: parent.right
            height: frame.headerHeight
            source: frame.headerSource
            onLoaded: item.controller = Qt.binding(() => frame.controller)
        }

        component ControlBackground: Item {
            required property var control
            required property color tint
            required property string symbol

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }

            Rectangle {
                anchors.centerIn: parent
                width: 12
                height: 12
                radius: 6
                color: parent.tint
                opacity: parent.control.hovered || parent.control.down ? 0 : 1
                Behavior on opacity {
                    NumberAnimation { duration: 180; easing.type: Easing.InOutQuad }
                }
            }
            Icon.Tinted {
                anchors.centerIn: parent
                width: 15
                height: 15
                opacity: parent.control.hovered || parent.control.down ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation { duration: 180; easing.type: Easing.InOutQuad }
                }
                source: "window-" + parent.symbol + ".svg"
                tint: parent.tint
            }
        }

        Loader {
            id: contentLoader
            anchors.fill: parent
            anchors.margins: frame.contentMargin
            anchors.topMargin: header.height + frame.contentTopGap
            source: frame.contentSource
        }

    }

    // Ubuntu owns the actual move/resize operation and its Wayland input grab.
    Repeater {
        model: [Qt.LeftEdge, Qt.RightEdge, Qt.TopEdge, Qt.BottomEdge,
                Qt.TopEdge | Qt.LeftEdge, Qt.TopEdge | Qt.RightEdge,
                Qt.BottomEdge | Qt.LeftEdge, Qt.BottomEdge | Qt.RightEdge]

        delegate: MouseArea {
            required property int modelData
            objectName: "windowResize-" + modelData
            z: 100
            hoverEnabled: true
            readonly property bool horizontal: (modelData & (Qt.LeftEdge | Qt.RightEdge)) !== 0
            readonly property bool vertical: (modelData & (Qt.TopEdge | Qt.BottomEdge)) !== 0
            visible: !frame.maximized
            width: horizontal ? (vertical ? frame.resizeCorner : frame.resizeBorder) : Math.max(0, frame.width - frame.resizeCorner * 2)
            height: vertical ? (horizontal ? frame.resizeCorner : frame.resizeBorder) : Math.max(0, frame.height - frame.resizeCorner * 2)
            x: (modelData & Qt.RightEdge) ? frame.width - width : horizontal ? 0 : frame.resizeCorner
            y: (modelData & Qt.BottomEdge) ? frame.height - height : vertical ? 0 : frame.resizeCorner
            cursorShape: horizontal && vertical
                ? ((modelData === (Qt.TopEdge | Qt.LeftEdge) || modelData === (Qt.BottomEdge | Qt.RightEdge)) ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor)
                : horizontal ? Qt.SizeHorCursor : Qt.SizeVerCursor
            acceptedButtons: Qt.LeftButton
            onPressed: frame.startSystemResize(modelData)
        }
    }
}
