import QtQuick
import gui
import "@COMPONENTS@" as Components

Components.Application {
    id: root
    title: "Pedro restore check"
    property int runs: 0
    property int failures: 0
    property bool checking: false
    property var targetWindow: null

    Component.onCompleted: {
        Backend.openPreview("@ONE@", [], true);
        Backend.openPreview("@TWO@", [], true);
    }

    Timer {
        interval: 300
        running: true
        repeat: true
        onTriggered: {
            if (root.previewWindows.length !== 2 || root.previewWindows.some(loader => !loader.item || loader.session.busy || !loader.item.item)) return;
            if (root.checking) {
                const passed = Diagnostic.focusedWindow === root.targetWindow;
                if (!passed) ++root.failures;
                console.log("RESTORE", root.runs, passed ? "PASS" : "FAIL");
                root.checking = false;
                if (root.runs >= 40) {
                    console.log("RESTORE SUMMARY", root.runs, "failures", root.failures);
                    for (const loader of root.previewWindows.slice()) loader.item.item.close();
                    running = false;
                    Qt.callLater(() => Qt.exit(root.failures ? 1 : 0));
                }
                return;
            }
            const index = root.runs % 2;
            const loader = root.previewWindows[index];
            root.targetWindow = loader.item.item;
            root.targetWindow.showMinimized();
            Backend.openPreview(loader.session.source, [], true);
            if (root.runs >= 30) {
                // A later open must supersede a restoration still awaiting focus.
                const other = root.previewWindows[1 - index];
                root.targetWindow = other.item.item;
                Backend.openPreview(other.session.source, [], true);
            }
            ++root.runs;
            root.checking = true;
        }
    }
}
