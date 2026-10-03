import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

import "about" as About
import "bluetooth" as Bluetooth
import "control" as Control
import "files" as Files
import "sound" as Sound
import "system" as System
import "wifi" as Wifi
import "../scripts/theme.js" as Theme

Rectangle {
    id: root
    color: "transparent"

    property Item backdrop
    property string mode
    property int availableWidth
    property int availableHeight
    readonly property bool controlMode: mode === "quick" || mode === "wifi" || mode === "bluetooth" || mode === "sound" || mode === "network"

    signal networkSettingsRequested
    signal closeRequested
    signal modeRequested(string mode)

    visible: mode !== ""
    implicitWidth: Math.max(0, Math.min(mode === "battery" ? 240 : mode === "network" ? 300 : mode === "quick" ? 328 : controlMode ? 304 : mode === "system" ? 288 : 320, availableWidth - 24))
    implicitHeight: Math.max(0, Math.min(mode === "battery" ? 140 : mode === "quick" ? control.implicitHeight + 24 : mode === "wifi" ? wifi.implicitHeight + 24 : mode === "bluetooth" ? bluetooth.implicitHeight + 24 : mode === "sound" ? 76 : mode === "network" ? 254 : mode === "system" ? 288 : mode === "notifications" || mode === "calendar" ? 180 : 380, availableHeight - 20))

    width: implicitWidth
    height: implicitHeight

    Behavior on height {
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
        }
    }

    Liquid {
        anchors.fill: parent
        frosted: true
        backdrop: root.backdrop
        cornerRadius: 18
    }

    HoverHandler {
        id: panelHover
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        hoverEnabled: true
        cursorShape: Qt.ArrowCursor
        preventStealing: true
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: root.controlMode ? 0 : 8

        RowLayout {
            Layout.fillWidth: true
            visible: !root.controlMode
            Label {
                text: root.mode === "battery" ? qsTranslate("Pedro", "shell.battery.title") : root.mode === "notifications" ? qsTranslate("Pedro", "shell.notifications.title") : root.mode === "calendar" ? qsTranslate("Pedro", "shell.calendar.title") : root.mode === "files" ? qsTranslate("Pedro", "app.files.name") : root.mode === "about" ? qsTranslate("Pedro", "shell.panel.about") : qsTranslate("Pedro", "shell.panel.system")
                color: Theme.white
                font.pixelSize: 16
                font.weight: Font.Medium
            }

            Item {
                Layout.fillWidth: true
            }

            Button {
                id: closeButton
                text: "×"
                onClicked: root.closeRequested()
                contentItem: Label {
                    text: closeButton.text
                    color: Theme.white
                    font.pixelSize: 18
                    horizontalAlignment: Qt.AlignHCenter
                    verticalAlignment: Qt.AlignVCenter
                }
                background: Rectangle {
                    radius: 8
                    color: closeButton.down ? Theme.overlayPressed : closeButton.hovered ? Theme.overlayHover : "transparent"
                }
                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.mode === "files" ? 1 : root.mode === "about" ? 2 : root.mode === "quick" ? 3 : root.mode === "wifi" ? 4 : root.mode === "bluetooth" ? 5 : root.mode === "sound" ? 6 : root.mode === "network" ? 7 : root.mode === "notifications" ? 8 : root.mode === "calendar" ? 9 : root.mode === "battery" ? 10 : 0

            System.View {}
            Files.View {}
            About.View {}
            ScrollView {
                id: controlScroll

                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                Control.Center {
                    id: control
                    width: controlScroll.availableWidth
                    height: Math.max(controlScroll.availableHeight, implicitHeight)
                    onSettingsRequested: root.networkSettingsRequested()
                    onWifiRequested: root.modeRequested(Backend.networkConnection.type === "wifi" || (Backend.networkConnection.type === "none" && Backend.wifiAvailable) ? "wifi" : "network")
                    onBluetoothRequested: root.modeRequested("bluetooth")
                }
            }
            Wifi.View {
                id: wifi
                onSettingsRequested: root.networkSettingsRequested()
                onBackRequested: root.modeRequested("quick")
            }
            Bluetooth.View {
                id: bluetooth
                onBackRequested: root.modeRequested("quick")
                onSettingsRequested: control.notice = qsTranslate("Pedro", "bluetooth.settings.pending")
                onDeviceRequested: name => control.notice = name
            }
            Sound.View {}
            Loader {
                source: "network/popup.qml"
                onLoaded: {
                    item.menuHovered = Qt.binding(() => panelHover.hovered);
                    item.settingsRequested.connect(root.networkSettingsRequested);
                }
            }
            Label {
                text: qsTranslate("Pedro", "shell.notifications.empty")
                color: Theme.textMuted
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.Wrap
            }
            Label {
                text: qsTranslate("Pedro", "shell.calendar.pending")
                color: Theme.textMuted
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.Wrap
            }
            Item {}
        }
    }
}
