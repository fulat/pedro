import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import gui
import "../menu" as Menu
import "../../logic/theme.js" as Theme

Item {
    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        TextField {
            id: pathField
            Layout.fillWidth: true
            text: Papi.documentPath
            color: Theme.white
            placeholderText: "Ruta absoluta del archivo"
            placeholderTextColor: Theme.textMuted
            onEditingFinished: Papi.documentPath = text
            background: Rectangle { radius: 8; color: Theme.overlayPressed; border.color: Theme.dividerSoft }
        }
        RowLayout {
            Layout.fillWidth: true
            Menu.Button {
                text: "Abrir"
                onClicked: {
                    Papi.documentPath = pathField.text
                    Papi.loadDocument()
                }
            }
            Menu.Button {
                text: "Guardar"
                onClicked: {
                    Papi.documentPath = pathField.text
                    Papi.saveDocument(editor.text)
                }
            }
            Item { Layout.fillWidth: true }
        }
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            TextArea {
                id: editor
                text: Papi.documentText
                color: Theme.white
                selectionColor: Theme.accent
                selectedTextColor: Theme.selectionText
                placeholderText: "Escribe aquí y guarda mediante PAPI…"
                placeholderTextColor: Theme.textMuted
                wrapMode: TextEdit.Wrap
                background: Rectangle { radius: 9; color: Theme.inputBackground; border.color: Theme.dividerSoft }
            }
        }
        Connections {
            target: Papi
            function onDocumentTextChanged() { editor.text = Papi.documentText }
        }
        Label {
            Layout.fillWidth: true
            text: Papi.statusMessage.length ? Papi.statusMessage : "Listo"
            color: Theme.white
            font.pixelSize: 10
            elide: Text.ElideMiddle
        }
    }
}
