pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import ".." as Components
import "../icon" as Icon
import "../../scripts/theme.js" as Theme

// A Pedro system confirmation. Content and actions belong to its caller.
Window {
    id: confirmation
    property Window ownerWindow: null
    property string message
    property string detail
    property string confirmText: title
    property string cancelText: qsTranslate("Pedro", "common.cancel")
    property bool actionEnabled: true
    property bool resolved: true
    signal accepted()
    signal rejected()

    objectName: "pedroConfirmation"
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint | Qt.CustomizeWindowHint | Qt.WindowCloseButtonHint
    transientParent: null
    modality: Qt.NonModal
    visible: false
    readonly property real preferredWidth: Math.min(400, Screen.desktopAvailableWidth || 400)
    width: preferredWidth
    height: Math.min(body.implicitHeight + 74, Screen.desktopAvailableHeight || 600)
    minimumWidth: preferredWidth
    maximumWidth: preferredWidth
    minimumHeight: Math.min(164, Screen.desktopAvailableHeight || 600)
    maximumHeight: Screen.desktopAvailableHeight || 600

    function open() {
        if (!visible) {
            resolved = false;
            if (ownerWindow) {
                x = Math.round(ownerWindow.x + (ownerWindow.width - width) / 2);
                y = Math.round(ownerWindow.y + (ownerWindow.height - height) / 2);
            }
            x = Math.max(Screen.virtualX, Math.min(x, Screen.virtualX + Screen.desktopAvailableWidth - width));
            y = Math.max(Screen.virtualY, Math.min(y, Screen.virtualY + Screen.desktopAvailableHeight - height));
            show();
        }
        cancelButton.forceActiveFocus();
        raise();
        requestActivate();
    }

    function accept() {
        if (!visible || resolved || !actionEnabled) return;
        resolved = true;
        close();
        accepted();
    }

    function reject() {
        if (!visible || resolved) return;
        resolved = true;
        close();
        rejected();
    }

    onClosing: {
        if (!resolved) {
            resolved = true;
            rejected();
        }
    }

    Shortcut { sequence: "Escape"; enabled: confirmation.visible; onActivated: confirmation.reject() }
    Shortcut {
        sequences: ["Return", "Enter"]
        enabled: confirmation.visible
        onActivated: {
            if (acceptButton.activeFocus) confirmation.accept();
            else confirmation.reject();
        }
    }

    Image {
        id: wallpaper
        anchors.fill: parent
        source: Backend.wallpaper
        fillMode: Image.PreserveAspectCrop
        smooth: true
        visible: false
    }
    Components.Liquid {
        anchors.fill: parent
        backdrop: wallpaper
        frosted: true
        cornerRadius: 14
    }
    Rectangle {
        anchors.fill: parent
        radius: 14
        color: Backend.appearanceMode === "light" ? "#52eff4fc" : "#45101825"
        border.color: Theme.liquidEdge
    }
    Connections {
        target: confirmation.ownerWindow
        function onVisibleChanged() {
            if (!confirmation.ownerWindow.visible) confirmation.reject();
        }
    }
    Item {
        width: parent.width
        height: 34
        DragHandler {
            objectName: "confirmationDrag"
            target: null
            onActiveChanged: { if (active) confirmation.startSystemMove(); }
        }
        Controls.Button {
            id: closeButton
            objectName: "confirmationClose"
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 22; height: 26
            hoverEnabled: true
            Accessible.name: qsTranslate("Pedro", "common.close")
            onClicked: confirmation.reject()
            contentItem: Item {}
            background: Item {
                Rectangle {
                    anchors.centerIn: parent
                    width: 12; height: 12
                    radius: 6
                    color: "#ff5c5f"
                    visible: !closeButton.hovered
                }
                Icon.Tinted {
                    anchors.centerIn: parent
                    width: 15; height: 15
                    source: "window-close.svg"
                    tint: "#ff5c5f"
                    visible: closeButton.hovered
                }
            }
        }
        Text {
            anchors.left: parent.left
            anchors.leftMargin: 42
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: confirmation.title
            color: Backend.appearanceMode === "light" ? "#10164d" : "#eef3ff"
            font.pixelSize: 13
            font.weight: Font.Medium
            elide: Text.ElideRight
            textFormat: Text.PlainText
        }
    }
    ColumnLayout {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        anchors.topMargin: 52
        spacing: 14
        Text {
            Layout.fillWidth: true
            text: confirmation.message
            color: Backend.appearanceMode === "light" ? "#263b63" : "#dce6f6"
            font.pixelSize: 13
            lineHeight: 1.3
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
        }
        Text {
            visible: text.length > 0
            Layout.fillWidth: true
            text: confirmation.detail
            color: Backend.appearanceMode === "light" ? "#536baa" : "#a5b7db"
            font.pixelSize: 12
            wrapMode: Text.WrapAnywhere
            textFormat: Text.PlainText
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 7
            spacing: 10
            Item { Layout.fillWidth: true }
            Action {
                id: cancelButton
                objectName: "confirmationCancel"
                text: confirmation.cancelText
                onClicked: confirmation.reject()
            }
            Action {
                id: acceptButton
                objectName: "confirmationAccept"
                text: confirmation.confirmText
                primary: true
                enabled: confirmation.actionEnabled
                onClicked: confirmation.accept()
            }
        }
    }
    component Action: Controls.Button {
        id: button
        property bool primary: false
        implicitWidth: Math.max(104, contentItem.implicitWidth + 30)
        implicitHeight: 32
        hoverEnabled: true
        contentItem: Text {
            text: button.text
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: button.primary ? "white" : Backend.appearanceMode === "light" ? "#10164d" : "#eef3ff"
            font.pixelSize: 13
            font.weight: Font.Medium
        }
        background: Rectangle {
            radius: 8
            color: button.primary ? "#0877ff" : button.hovered ? "#35ffffff" : "#20ffffff"
            border.color: button.activeFocus ? "#99ffffff" : button.primary ? "transparent" : Theme.liquidEdge
            opacity: button.enabled ? 1 : 0.45
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
    }
}
