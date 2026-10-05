pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import ".." as Components
import "../../scripts/theme.js" as Theme

// A Pedro system confirmation. Content and actions belong to its caller.
Window {
    id: confirmation
    property Window ownerWindow: null
    property string message
    property real progress: -1
    property string detail
    property string confirmText: qsTranslate("Pedro", "common.ok")
    property bool showCancel: true
    property string cancelText: qsTranslate("Pedro", "common.cancel")
    property bool blocking: true
    property bool keepOnTop: true
    property bool actionEnabled: true
    property bool resolved: true
    signal accepted()
    signal rejected()

    objectName: "pedroConfirmation"
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint | Qt.CustomizeWindowHint | (keepOnTop ? Qt.WindowStaysOnTopHint : 0)
    transientParent: null
    modality: blocking ? Qt.ApplicationModal : Qt.NonModal
    visible: false
    readonly property real preferredWidth: Math.min(360, Screen.desktopAvailableWidth || 360)
    width: preferredWidth
    height: Math.min(Math.max(220, body.implicitHeight + 82), Screen.desktopAvailableHeight || 600)
    minimumWidth: preferredWidth
    maximumWidth: preferredWidth
    minimumHeight: Math.min(220, Screen.desktopAvailableHeight || 600)
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
        if (showCancel) cancelButton.forceActiveFocus();
        else acceptButton.forceActiveFocus();
        activateAlert();
    }

    function activateAlert() {
        if (!visible || resolved) return;
        raise();
        requestActivate();
        if (typeof Backend.activateWindow === "function") Backend.activateWindow(confirmation);
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

    Connections {
        target: Qt.application
        function onStateChanged() {
            if (Qt.application.state === Qt.ApplicationActive && confirmation.visible && confirmation.blocking) confirmation.activateAlert();
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
        cornerRadius: 16
    }
    Rectangle {
        anchors.fill: parent
        radius: 16
        color: Backend.appearanceMode === "light" ? Theme.menuGlassLightHaze : Theme.menuGlassHaze
        border.color: Theme.liquidEdge
    }
    Connections {
        target: confirmation.ownerWindow
        function onActiveChanged() {
            if (confirmation.ownerWindow.active && confirmation.blocking && confirmation.visible) confirmation.activateAlert();
        }
        function onVisibleChanged() {
            if (!confirmation.ownerWindow.visible) confirmation.reject();
        }
    }
    Item {
        width: parent.width
        height: 44
        DragHandler {
            objectName: "confirmationDrag"
            target: null
            onActiveChanged: { if (active) confirmation.startSystemMove(); }
        }
        Text {
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            text: confirmation.title
            horizontalAlignment: Text.AlignLeft
            color: Backend.appearanceMode === "light" ? "#10164d" : "#eef3ff"
            font.pixelSize: 13
            font.weight: Font.Medium
            elide: Text.ElideRight
            textFormat: Text.PlainText
        }
    }
    Rectangle {
        x: 16
        y: 44
        width: parent.width - 32
        height: 1
        color: Theme.dividerSoft
    }
    ColumnLayout {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        anchors.topMargin: 58
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        spacing: 12
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignLeft
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
        Controls.ProgressBar {
            Layout.fillWidth: true
            visible: confirmation.progress >= 0
            value: Math.max(0, Math.min(1, confirmation.progress))
            padding: 0
            background: Rectangle { implicitHeight: 6; radius: 3; color: Theme.sliderTrack }
            contentItem: Item {
                implicitHeight: 6
                Rectangle { width: parent.width * Math.max(0, Math.min(1, confirmation.progress)); height: 6; radius: 3; color: Theme.sliderFill }
            }
        }
        Item { Layout.fillHeight: true }
        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 2
            implicitHeight: 1
            color: Theme.dividerSoft
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 1
            spacing: 10
            Item { Layout.fillWidth: true }
            Action {
                id: cancelButton
                objectName: "confirmationCancel"
                visible: confirmation.showCancel
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
        implicitHeight: 34
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
            radius: 17
            color: button.primary ? Theme.switchActive : Theme.cardSurface
            border.color: button.activeFocus ? Theme.switchActiveBorder : button.primary ? Theme.switchActiveBorder : Theme.buttonBorder
            opacity: button.enabled ? 1 : 0.45
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: button.down ? Theme.overlayPressed : button.hovered ? Theme.overlayHover : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }
            }
        }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
    }
}
