import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "../about" as About
import "../bluetooth" as Bluetooth
import "../control" as Control
import "../files" as Files
import "../glass" as Glass
import "../sound" as Sound
import "../system" as System
import "../wifi" as Wifi
import "../logic/theme.js" as Theme

Item {
    id: root
    property string mode
    property int availableWidth
    property int availableHeight
    property Item backdrop
    property real anchorX
    readonly property bool controlMode: mode === "quick" || mode === "wifi"
                                        || mode === "bluetooth" || mode === "sound"
    signal closeRequested()
    signal modeRequested(string mode)

    visible: mode !== ""
    width: Math.min(360, availableWidth - 24)
    height: Math.min(mode === "quick" ? 594
                     : mode === "wifi" ? 520
                     : mode === "bluetooth" ? 360
                     : mode === "sound" ? 92 : 420,
                     availableHeight - 20)
    Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    Glass.Surface {
        anchors.fill: parent
        backdrop: root.backdrop
        radius: root.controlMode ? 16 : 12
        tint: root.controlMode ? Theme.controlSurface : Theme.glass
        stroke: root.controlMode ? "#705f7692" : Theme.glassBorder
        pointerVisible: true
        pointerX: root.anchorX - root.x
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
                color: Theme.textPrimary
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
                    color: Theme.textPrimary
                    font.pixelSize: 18
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    radius: 8
                    color: closeButton.hovered ? "#24ffffff" : "transparent"
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
            Control.Center {
                id: control
                onSettingsRequested: root.modeRequested("about")
                onWifiRequested: root.modeRequested("wifi")
                onBluetoothRequested: root.modeRequested("bluetooth")
            }
            Wifi.View {
                onBackRequested: root.modeRequested("quick")
            }
            Bluetooth.View {
                bluetoothEnabled: control.bluetoothEnabled
                onBackRequested: root.modeRequested("quick")
                onBluetoothEnabledRequested: state => control.bluetoothEnabled = state
                onOptionRequested: option => control.notice = option + " · pendiente de conexión con PAPI"
            }
            Sound.View {}
        }
    }
}
