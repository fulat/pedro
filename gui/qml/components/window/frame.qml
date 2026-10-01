pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import QtQuick.Controls.Basic as Controls
import ".." as Components
import "../icon" as Icon
import "../../scripts/theme.js" as Theme

Window {
    id: frame

    property url contentSource
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
        backdrop: windowBackdrop
        frosted: true
        cornerRadius: frame.maximized ? 0 : 14
    }

    Item {
        id: header
        width: parent.width
        height: 44

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
                Accessible.name: "Cerrar"
                onClicked: frame.close()
                background: ControlBackground { control: closeControl; tint: "#ff5c5f"; symbol: "close" }
            }
            Controls.Button {
                id: minimizeControl
                objectName: "windowMinimize"
                width: 20
                height: 28
                hoverEnabled: true
                Accessible.name: "Minimizar"
                onClicked: frame.showMinimized()
                background: ControlBackground { control: minimizeControl; tint: "#fac800"; symbol: "minimize" }
            }
            Controls.Button {
                id: maximizeControl
                objectName: "windowMaximize"
                width: 20
                height: 28
                hoverEnabled: true
                Accessible.name: frame.maximized ? "Restaurar" : "Maximizar"
                onClicked: frame.toggleMaximized()
                background: ControlBackground {
                    control: maximizeControl
                    tint: frame.maximized ? "#2396f3" : "#35c759"
                    symbol: frame.maximized ? "restore" : "maximize"
                }
            }
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 90
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            text: frame.title
            color: Theme.white
            font.pixelSize: 13
            font.weight: Font.Medium
            elide: Text.ElideRight
        }
    }

    component ControlBackground: Item {
        required property var control
        required property color tint
        required property string symbol

        Rectangle {
            anchors.centerIn: parent
            width: 12
            height: 12
            radius: 6
            color: parent.control.hovered || parent.control.down ? "#4a4a4f" : parent.tint
            Behavior on color {
                ColorAnimation { duration: 180; easing.type: Easing.InOutQuad }
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
        anchors.fill: parent
        anchors.margins: 12
        anchors.topMargin: header.height + 6
        source: frame.contentSource
    }

    // Ubuntu owns the actual move/resize operation and its Wayland input grab.
    Repeater {
        model: [Qt.LeftEdge, Qt.RightEdge, Qt.TopEdge, Qt.BottomEdge,
                Qt.TopEdge | Qt.LeftEdge, Qt.TopEdge | Qt.RightEdge,
                Qt.BottomEdge | Qt.LeftEdge, Qt.BottomEdge | Qt.RightEdge]

        delegate: MouseArea {
            required property int modelData
            readonly property bool horizontal: (modelData & (Qt.LeftEdge | Qt.RightEdge)) !== 0
            readonly property bool vertical: (modelData & (Qt.TopEdge | Qt.BottomEdge)) !== 0
            visible: !frame.maximized
            width: horizontal ? (vertical ? 12 : 6) : frame.width - 24
            height: vertical ? (horizontal ? 12 : 6) : frame.height - 24
            x: (modelData & Qt.RightEdge) ? frame.width - width : horizontal ? 0 : 12
            y: (modelData & Qt.BottomEdge) ? frame.height - height : vertical ? 0 : 12
            cursorShape: horizontal && vertical
                ? ((modelData === (Qt.TopEdge | Qt.LeftEdge) || modelData === (Qt.BottomEdge | Qt.RightEdge)) ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor)
                : horizontal ? Qt.SizeHorCursor : Qt.SizeVerCursor
            acceptedButtons: Qt.LeftButton
            onPressed: frame.startSystemResize(modelData)
        }
    }
}
