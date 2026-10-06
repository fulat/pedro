import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import gui
import "../../controllers" as Controllers
import "../menu" as Menu
import "../../scripts/theme.js" as Theme

Item {
    // Connects document controls and backend notifications to one controller.
    Controllers.Files {
        id: controller
        pathField: pathField
        editor: editor
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        TextField {
            id: pathField
            Layout.fillWidth: true
            text: Papi.documentPath
            color: Theme.white
            placeholderText: qsTranslate("Pedro", "files.editor.pathPlaceholder")
            placeholderTextColor: Theme.textMuted
            onEditingFinished: controller.updatePath()
            background: Rectangle {
                radius: 8
                color: Theme.overlayPressed
                border.color: Theme.dividerSoft
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Menu.Button {
                text: qsTranslate("Pedro", "common.open")
                onClicked: controller.openDocument()
            }
            Menu.Button {
                text: qsTranslate("Pedro", "common.save")
                onClicked: controller.saveDocument()
            }
            Item {
                Layout.fillWidth: true
            }
        }
        ScrollView {
            id: editorScroll
            Binding { target: editorScroll.contentItem; property: "boundsBehavior"; value: Flickable.StopAtBounds }
            Binding { target: editorScroll.contentItem; property: "boundsMovement"; value: Flickable.StopAtBounds }
            Layout.fillWidth: true
            Layout.fillHeight: true
            TextArea {
                id: editor
                text: Papi.documentText
                color: Theme.white
                selectionColor: Theme.accent
                selectedTextColor: Theme.selectionText
                placeholderText: qsTranslate("Pedro", "files.editor.contentPlaceholder")
                placeholderTextColor: Theme.textMuted
                wrapMode: TextEdit.Wrap
                background: Rectangle {
                    radius: 9
                    color: Theme.inputBackground
                    border.color: Theme.dividerSoft
                }
            }
        }
        Label {
            Layout.fillWidth: true
            text: Papi.statusMessage.length ? Papi.statusMessage : qsTranslate("Pedro", "common.done")
            color: Theme.white
            font.pixelSize: 10
            elide: Text.ElideMiddle
        }
    }
}
