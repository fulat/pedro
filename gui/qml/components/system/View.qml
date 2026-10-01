import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import gui
import "../metric" as Metric
import "../../scripts/theme.js" as Theme

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
            Metric.Card { label: qsTranslate("Pedro", "system.metrics.cpu"); value: Papi.cpuUsage < 0 ? qsTranslate("Pedro", "system.metrics.measuring") : Papi.cpuUsage.toFixed(1) + "%" }
            Metric.Card { label: qsTranslate("Pedro", "system.metrics.memory"); value: Papi.memoryUsage.toFixed(1) + "%" }
            Metric.Card { label: qsTranslate("Pedro", "system.metrics.uptime"); value: Papi.uptime }
            Metric.Card { label: qsTranslate("Pedro", "system.metrics.architecture"); value: Papi.architecture }
        }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.dividerSoft }
        Label { text: qsTranslate("Pedro", "system.metrics.kernel"); color: Theme.textMuted; font.pixelSize: 10 }
        Label {
            Layout.fillWidth: true
            text: Papi.kernel
            color: Theme.white
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }
        Label { text: Papi.memorySummary; color: Theme.textMuted; font.pixelSize: 11 }
        Item { Layout.fillHeight: true }
        Label {
            Layout.fillWidth: true
            text: qsTranslate("Pedro", "system.info.caption")
            color: Theme.textMuted
            font.pixelSize: 10
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
