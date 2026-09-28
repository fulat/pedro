import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import gui
import "../metric" as Metric
import "../logic/theme.js" as Theme

Item {
    ColumnLayout {
        anchors.fill: parent
        spacing: 9

        Label {
            Layout.fillWidth: true
            text: Papi.hostname
            color: Theme.accent
            font.pixelSize: 13
            font.weight: Font.Medium
        }
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 10
            rowSpacing: 10
            Metric.Card { label: "CPU"; value: Papi.cpuUsage < 0 ? "Midiendo…" : Papi.cpuUsage.toFixed(1) + "%" }
            Metric.Card { label: "Memoria"; value: Papi.memoryUsage.toFixed(1) + "%" }
            Metric.Card { label: "Tiempo activo"; value: Papi.uptime }
            Metric.Card { label: "Arquitectura"; value: Papi.architecture }
        }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: "#28ffffff" }
        Label { text: "Núcleo"; color: "#d6dcdf"; font.pixelSize: 10 }
        Label {
            Layout.fillWidth: true
            text: Papi.kernel
            color: "#ffffff"
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }
        Label { text: Papi.memorySummary; color: "#d6dcdf"; font.pixelSize: 11 }
        Item { Layout.fillHeight: true }
        Label {
            Layout.fillWidth: true
            text: "Información real de Ubuntu a través de PAPI"
            color: "#d6dcdf"
            font.pixelSize: 10
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
