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

    signal closeRequested
    signal modeRequested(string mode)

    visible: mode !== ""
    width: Math.min(mode === "quick" ? 368 : controlMode ? 352 : 320, availableWidth - 24)
    height: Math.min(mode === "quick" ? 604 : mode === "wifi" ? 460 : mode === "bluetooth" ? 460 : mode === "sound" ? 84 : 380, availableHeight - 20)

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

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        preventStealing: true
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.controlMode ? 14 : 12
        spacing: root.controlMode ? 0 : 10

        RowLayout {
            Layout.fillWidth: true
            visible: !root.controlMode
            Label {
                text: root.mode === "files" ? qsTranslate("Pedro", "app.files.name") : root.mode === "about" ? qsTranslate("Pedro", "shell.panel.about") : qsTranslate("Pedro", "shell.panel.system")
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
            currentIndex: root.mode === "files" ? 1 : root.mode === "about" ? 2 : root.mode === "quick" ? 3 : root.mode === "wifi" ? 4 : root.mode === "bluetooth" ? 5 : root.mode === "sound" ? 6 : root.mode === "network" ? 7 : 0

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
                    onSettingsRequested: root.modeRequested("about")
                    onWifiRequested: root.modeRequested(Backend.networkConnection.type === "wifi" || (Backend.networkConnection.type === "none" && Backend.wifiAvailable) ? "wifi" : "network")
                    onBluetoothRequested: root.modeRequested("bluetooth")
                }
            }
            Wifi.View {
                onBackRequested: root.modeRequested("quick")
            }
            Bluetooth.View {
                onBackRequested: root.modeRequested("quick")
                onSettingsRequested: control.notice = qsTranslate("Pedro", "bluetooth.settings.pending")
                onDeviceRequested: name => control.notice = name
            }
            Sound.View {}
            ColumnLayout {
                Label {
                    text: Backend.networkConnection.type === "ethernet" ? "Ethernet" : qsTranslate("Pedro", "network.connection.title")
                    color: Theme.white
                    font.pixelSize: 20
                }
                Label {
                    text: Backend.networkConnection.name || qsTranslate("Pedro", "network.connection.none")
                    color: Theme.textMuted
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                }
                Item { Layout.fillHeight: true }
            }
        }
    }
}
