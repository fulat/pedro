import QtQuick
import gui

// Coordinates document operations for the files view.
QtObject {
    id: controller

    required property var pathField
    required property var editor

    // Synchronizes an edited path with PAPI.
    function updatePath() {
        Papi.documentPath = pathField.text;
    }

    // Loads the document selected by the current path field.
    function openDocument() {
        updatePath();
        Papi.loadDocument();
    }

    // Saves the editor contents through PAPI.
    function saveDocument() {
        updatePath();
        Papi.saveDocument(editor.text);
    }

    // Mirrors backend document changes into the editor.
    function documentTextChanged() {
        editor.text = Papi.documentText;
    }

    // Keeps backend notifications out of the visual component.
    property Connections backendConnections: Connections {
        target: Papi
        function onDocumentTextChanged() {
            controller.documentTextChanged();
        }
    }
}
