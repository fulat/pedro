import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "../about" as About
import "../bluetooth" as Bluetooth
import "../control" as Control
import "../files" as Files
import "../sound" as Sound
import "../system" as System
import "../wifi" as Wifi

Item {
    id: root
    property string mode
    property int availableWidth
    property int availableHeight
    readonly property bool controlMode: mode === "quick" || mode === "wifi"
                                        || mode === "bluetooth" || mode === "sound"
    signal closeRequested()
    signal modeRequested(string mode)

    visible: mode !== ""
    width: Math.min(mode === "quick" ? 430 : controlMode ? 408 : 360, availableWidth - 24)
    height: Math.min(mode === "quick" ? 704
                     : mode === "wifi" ? 520
                     : mode === "bluetooth" ? 520
                     : mode === "sound" ? 92 : 420,
                     availableHeight - 20)
    Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    Rectangle {
        x: -7
        y: 6
        width: root.width + 14
        height: root.height + 5
        radius: 24
        color: "#18000000"
    }

    Rectangle {
        x: -3
        y: 3
        width: root.width + 6
        height: root.height + 2
        radius: 21
        color: "#2a000000"
    }

    Rectangle {
        anchors.fill: parent
        radius: 18
        gradient: Gradient {
            GradientStop { position: 0; color: "#e8383838" }
            GradientStop { position: 0.55; color: "#e82c2c2c" }
            GradientStop { position: 1; color: "#e8202020" }
        }
        border.width: 1
        border.color: "#526f6f6f"
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        preventStealing: true
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.controlMode ? 16 : 14
        spacing: root.controlMode ? 0 : 10

        RowLayout {
            Layout.fillWidth: true
            visible: !root.controlMode
            Label {
                text: root.mode === "files" ? "Archivos" :
                      root.mode === "about" ? "Pedro OS" : "Sistema"
                color: "#ffffff"
                font.pixelSize: 16
                font.weight: Font.Medium
            }
            Item { Layout.fillWidth: true }
            Button {
                id: closeButton
                text: "×"
                onClicked: root.closeRequested()
                contentItem: Label {
                    text: closeButton.text
                    color: "#ffffff"
                    font.pixelSize: 18
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    radius: 8
                    color: closeButton.down ? "#34ffffff"
                                            : closeButton.hovered ? "#22ffffff" : "transparent"
                }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.mode === "files" ? 1 :
                          root.mode === "about" ? 2 :
                          root.mode === "quick" ? 3 :
                          root.mode === "wifi" ? 4 :
                          root.mode === "bluetooth" ? 5 :
                          root.mode === "sound" ? 6 : 0

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
                    onWifiRequested: root.modeRequested("wifi")
                    onBluetoothRequested: root.modeRequested("bluetooth")
                }
            }
            Wifi.View {
                onBackRequested: root.modeRequested("quick")
            }
            Bluetooth.View {
                onBackRequested: root.modeRequested("quick")
                onSettingsRequested: control.notice = "Configuración de Bluetooth · pendiente"
                onDeviceRequested: name => control.notice = name
            }
            Sound.View {}
        }
    }
}
