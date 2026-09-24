pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import "../icon" as Icon
import "../option" as Option
import "../toggle" as Toggle
import "../logic/theme.js" as Theme

Item {
    id: root
    property bool bluetoothEnabled: true
    signal backRequested()
    signal bluetoothEnabledRequested(bool state)
    signal optionRequested(string option)

    ColumnLayout {
        anchors.fill: parent
        spacing: 2

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 64
            spacing: 12

            Rectangle {
                implicitWidth: 42
                implicitHeight: 42
                radius: 21
                color: backMouse.pressed ? "#35465c" : backMouse.containsMouse ? "#2b3b51" : "#4d1a2a40"
                border.width: 1
                border.color: "#385f7692"
                Icon.Tinted {
                    anchors.centerIn: parent
                    width: 10
                    height: 16
                    rotation: 180
                    source: "../../assets/icons/chevron.svg"
                }
                MouseArea {
                    id: backMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.backRequested()
                }
            }

            Controls.Label {
                Layout.fillWidth: true
                text: "Bluetooth"
                color: Theme.textPrimary
                font.pixelSize: 20
                font.weight: Font.DemiBold
            }

            Toggle.Switch {
                active: root.bluetoothEnabled
                onToggled: state => root.bluetoothEnabledRequested(state)
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.controlBorder
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 78
            Layout.leftMargin: 8
            Layout.rightMargin: 8
            spacing: 14
            Icon.Tinted {
                source: "../../assets/icons/bluetooth.svg"
                Layout.preferredWidth: 31
                Layout.preferredHeight: 31
                tint: root.bluetoothEnabled ? "#75adff" : "#aeb8c7"
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Controls.Label {
                    text: "Bluetooth"
                    color: Theme.textPrimary
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }
                Controls.Label {
                    text: root.bluetoothEnabled ? "Activado · visible para dispositivos" : "Desactivado"
                    color: Theme.textSecondary
                    font.pixelSize: 9
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.controlBorder
        }

        Option.Row {
            title: "Buscar dispositivos"
            icon: "../../assets/icons/search.svg"
            onActivated: root.optionRequested("Buscar dispositivos")
        }
        Option.Row {
            title: "Configuración de Bluetooth"
            icon: "../../assets/icons/settings.svg"
            onActivated: root.optionRequested("Configuración de Bluetooth")
        }

        Item { Layout.fillHeight: true }
    }
}
