import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "../logic/theme.js" as Theme

Item {
    ColumnLayout {
        anchors.fill: parent
        spacing: 10
        Item { Layout.fillHeight: true }
        Label {
            Layout.alignment: Qt.AlignHCenter
            text: "P"
            color: Theme.textPrimary
            font.pixelSize: 48
            font.weight: Font.Black
            font.italic: true
        }
        Label {
            Layout.alignment: Qt.AlignHCenter
            text: "Pedro OS"
            color: Theme.textPrimary
            font.pixelSize: 20
            font.weight: Font.Medium
        }
        Label {
            Layout.fillWidth: true
            text: "El escritorio está tomando forma. Wi-Fi ya consulta NetworkManager mediante PAPI; sonido, energía y búsqueda se conectarán conforme se implementen esas capacidades."
            color: Theme.textSecondary
            font.pixelSize: 12
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
        }
        Item { Layout.fillHeight: true }
    }
}
