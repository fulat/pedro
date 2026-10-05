pragma ComponentBehavior: Bound
import QtQuick
import "../confirmation" as Confirmation

Confirmation.Window {
    id: window
    objectName: "pedroTransfer"
    property var operation
    property bool wasBusy: false
    blocking: false
    keepOnTop: false
    showCancel: false
    title: qsTranslate("Pedro", operation && operation.busy ? "transfer.title" : "transfer.error")
    message: operation ? operation.busy ? operation.currentFile : operation.error : ""
    detail: operation && operation.busy ? qsTranslate("Pedro", "transfer.progress") : ""
    progress: operation && operation.busy ? operation.progress : -1
    confirmText: qsTranslate("Pedro", operation && operation.busy ? "common.cancel" : "common.close")
    onAccepted: {
        if (operation.busy) operation.cancel();
        else operation.dismissError();
    }
    onRejected: { if (operation && operation.busy) operation.cancel(); }
    Timer {
        id: delay
        interval: 300
        onTriggered: {
            if (!window.operation || !window.operation.busy) return;
            window.open();
        }
    }
    Connections {
        target: window.operation
        function onChanged() {
            if (window.operation.busy && !window.wasBusy) {
                window.wasBusy = true;
                delay.restart();
            } else if (!window.operation.busy && window.wasBusy) {
                window.wasBusy = false;
                delay.stop();
                if (!window.operation.error.length || window.operation.cancelled) {
                    window.resolved = true;
                    window.close();
                } else {
                    window.open();
                }
            }
        }
    }
}
