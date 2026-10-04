pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import ".." as Components
import "../icon" as Icon
import "../../scripts/theme.js" as Theme

Item {
    id: header
    property var controller
    readonly property var preview: controller ? controller.preview : null
    readonly property color ink: controller ? controller.ink : "#eef3ff"
    readonly property Item backdrop: Window.window ? Window.window.entryBackdrop : null
    readonly property bool ready: preview && !preview.busy && !preview.error.length
    readonly property bool compact: width < 670

    component Glass: Item {
        Components.Liquid {
            anchors.fill: parent
            backdrop: header.backdrop
            cornerRadius: height / 2
            frosted: true
            blurAmount: 0.65
            edgeColor: Backend.appearanceMode === "light" ? "#30ffffff" : "#28ffffff"
        }
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            gradient: Gradient {
                GradientStop { position: 0; color: "#12ffffff" }
                GradientStop { position: 1; color: "#04000000" }
            }
        }
    }

    component Action: Controls.ToolButton {
        id: action
        property string symbol
        property string label
        implicitWidth: header.compact ? 34 : 42
        implicitHeight: 28
        hoverEnabled: true
        Accessible.name: label
        Controls.ToolTip.visible: hovered
        Controls.ToolTip.text: label
        Controls.ToolTip.delay: 600
        contentItem: Icon.Tinted {
            source: action.symbol + ".svg"
            tint: header.ink
            opacity: action.enabled ? 1 : 0.35
            implicitWidth: 19
            implicitHeight: 19
        }
        background: Rectangle {
            radius: 18
            color: action.down ? Theme.controlPressed : action.hovered ? Theme.controlHover : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
    }

    component Entry: Controls.MenuItem {
        id: entry
        implicitHeight: 28
        contentItem: Controls.Label {
            text: entry.text
            color: header.ink
            opacity: entry.enabled ? 1 : 0.35
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: 8
            color: entry.highlighted || entry.hovered ? Theme.controlHover : "transparent"
        }
    }

    component Menu: Controls.Menu {
        width: 235
        padding: 7
        y: header.height - 2
        background: Components.Liquid {
            backdrop: header.backdrop
            frosted: true
            cornerRadius: 15
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.rightMargin: 12
        spacing: header.compact ? 7 : 12

        Controls.Label {
            Layout.fillWidth: true
            Layout.minimumWidth: 30
            text: header.preview ? header.preview.name : ""
            color: header.ink
            font.pixelSize: 12
            elide: Text.ElideMiddle
        }
        Glass {
            Layout.preferredWidth: header.compact ? 127 : 152
            Layout.preferredHeight: 28
            RowLayout {
                anchors.fill: parent
                spacing: 0
                Action {
                    objectName: "previewZoomOut"
                    symbol: "minus"
                    label: qsTranslate("Pedro", "preview.zoom.out")
                    enabled: header.ready && header.controller.zoom > 0.25
                    onClicked: header.controller.zoom = Math.max(0.25, header.controller.zoom / 1.25)
                }
                Rectangle { width: 1; height: 16; color: "#18ffffff" }
                Controls.ToolButton {
                    Layout.fillWidth: true
                    implicitHeight: 28
                    Accessible.name: qsTranslate("Pedro", "preview.fit")
                    onClicked: header.controller.zoom = 1
                    contentItem: Controls.Label {
                        text: header.controller ? Math.round(header.controller.zoom * 100) + "%" : "100%"
                        color: header.ink
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 12
                    }
                    background: null
                }
                Rectangle { width: 1; height: 16; color: "#18ffffff" }
                Action {
                    objectName: "previewZoomIn"
                    symbol: "zoom"
                    label: qsTranslate("Pedro", "preview.zoom.in")
                    enabled: header.ready && header.controller.zoom < 8
                    onClicked: header.controller.zoom = Math.min(8, header.controller.zoom * 1.25)
                }
            }
        }
        Rectangle { visible: !header.compact; Layout.preferredWidth: 1; Layout.preferredHeight: 28; color: "#20ffffff" }
        Glass {
            Layout.preferredWidth: header.compact ? 102 : 180
            Layout.preferredHeight: 28
            Row {
                anchors.centerIn: parent
                spacing: header.compact ? 0 : 3
                Action {
                    objectName: "previewRotate"
                    symbol: "rotate"
                    label: qsTranslate("Pedro", "preview.rotate")
                    enabled: header.ready
                    onClicked: header.controller.rotationAngle = (header.controller.rotationAngle + 90) % 360
                }
                Action {
                    objectName: "previewInformation"
                    symbol: "info"
                    label: qsTranslate("Pedro", "preview.information")
                    onClicked: information.open()
                }
                Action {
                    visible: !header.compact
                    symbol: "rename"
                    label: qsTranslate("Pedro", "preview.tools")
                    enabled: header.ready
                    onClicked: tools.open()
                }
                Action {
                    symbol: "upload"
                    label: qsTranslate("Pedro", "preview.share")
                    onClicked: sharing.open()
                }
            }
        }
        Glass {
            Layout.preferredWidth: header.compact ? 34 : 42
            Layout.preferredHeight: 28
            Action {
                anchors.fill: parent
                objectName: "previewMore"
                symbol: "more"
                label: qsTranslate("Pedro", "preview.more")
                onClicked: more.open()
            }
        }
    }

    Menu {
        id: tools
        x: Math.max(0, header.width - width - 60)
        Entry { text: qsTranslate("Pedro", "preview.rotate.left"); onTriggered: header.controller.rotationAngle = (header.controller.rotationAngle + 270) % 360 }
        Entry { text: qsTranslate("Pedro", "preview.rotate.right"); onTriggered: header.controller.rotationAngle = (header.controller.rotationAngle + 90) % 360 }
        Entry { text: qsTranslate("Pedro", "preview.flip"); onTriggered: header.controller.mirrored = !header.controller.mirrored }
        Entry { text: qsTranslate("Pedro", "preview.reset"); onTriggered: header.controller.resetImage() }
    }
    Menu {
        id: sharing
        x: Math.max(0, header.width - width - 12)
        Entry {
            text: qsTranslate("Pedro", "preview.copy")
            onTriggered: Backend.clipboard.copy([header.preview.source])
        }
    }
    Menu {
        id: more
        x: Math.max(0, header.width - width - 12)
        Entry { text: qsTranslate("Pedro", "preview.previous"); enabled: header.preview && header.preview.canPrevious; onTriggered: header.preview.previous() }
        Entry { text: qsTranslate("Pedro", "preview.next"); enabled: header.preview && header.preview.canNext; onTriggered: header.preview.next() }
        Controls.MenuSeparator {}
        Entry { text: qsTranslate("Pedro", "preview.fit"); onTriggered: header.controller.zoom = 1 }
        Entry { text: qsTranslate("Pedro", "preview.reset"); enabled: header.ready; onTriggered: header.controller.resetImage() }
        Entry { text: qsTranslate("Pedro", "preview.information"); onTriggered: information.open() }
    }
    Controls.Popup {
        id: information
        objectName: "previewInformationPopup"
        width: Math.min(330, header.width - 16)
        x: header.width - width - 12
        y: header.height - 2
        padding: 18
        closePolicy: Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutside
        background: Components.Liquid { backdrop: header.backdrop; frosted: true; cornerRadius: 16 }
        contentItem: Column {
            spacing: 10
            Controls.Label { width: parent.width; text: header.preview ? header.preview.name : ""; wrapMode: Text.WrapAnywhere; color: header.ink; font.bold: true }
            Controls.Label { text: header.preview ? header.preview.frameSize.width + " × " + header.preview.frameSize.height : ""; color: header.ink }
            Controls.Label { width: parent.width; text: header.preview ? header.preview.source.toString() : ""; color: header.ink; wrapMode: Text.WrapAnywhere; font.pixelSize: 11; opacity: 0.7 }
        }
    }

    Connections {
        target: header.Window.window
        function onVisibleChanged() {
            if (!header.Window.window.visible) {
                information.close();
                more.close();
                sharing.close();
                tools.close();
            }
        }
    }
}
