import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import gui
import "../menu" as Menu
import "../logic/theme.js" as Theme

Item {
    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        TextField {
            id: pathField
            Layout.fillWidth: true
            text: Papi.documentPath
            color: Theme.textPrimary
            placeholderText: "Ruta absoluta del archivo"
            placeholderTextColor: Theme.textSecondary
            onEditingFinished: Papi.documentPath = text
            background: Rectangle { radius: 8; color: "#34ffffff"; border.color: "#28ffffff" }
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
                color: Theme.textPrimary
                selectionColor: Theme.accent
                selectedTextColor: "#15191e"
                placeholderText: "Escribe aquí y guarda mediante PAPI…"
                placeholderTextColor: Theme.textSecondary
                wrapMode: TextEdit.Wrap
                background: Rectangle { radius: 9; color: "#2b000000"; border.color: "#28ffffff" }
            }
        }
        Connections {
            target: Papi
            function onDocumentTextChanged() { editor.text = Papi.documentText }
        }
        Label {
            Layout.fillWidth: true
            text: Papi.statusMessage.length ? Papi.statusMessage : "Listo"
            color: Theme.textPrimary
            font.pixelSize: 10
            elide: Text.ElideMiddle
        }
    }
}
