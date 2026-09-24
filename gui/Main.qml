import QtQuick
import QtQuick.Controls.Basic
import gui
import "qml/bar" as Bar
import "qml/panel" as Panel

ApplicationWindow {
    id: window
    width: 2000
    height: 1300
    minimumWidth: 2000
    minimumHeight: 1300
    visible: true
    title: qsTr("Pedro OS")
    visibility: Papi.developmentMode ? Window.Windowed : Window.FullScreen
    color: "#05080c"

    property string panelMode: ""
    property string panelSource: ""
    property real panelAnchorX: width - 190
    property date currentTime: new Date()

    function closePanel() {
        panelMode = "";
        panelSource = "";
    }

    function togglePanel(name, anchorX, source) {
        if (panelMode === name && panelSource === source) {
            closePanel();
            return;
        }

        panelAnchorX = anchorX;
        panelSource = source;
        panelMode = name;
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: window.currentTime = new Date()
    }

    Image {
        id: wallpaper
        anchors.fill: parent
        source: "assets/wallpaper.jpeg"
        fillMode: Image.PreserveAspectCrop
        smooth: true
        mipmap: true
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: "#19000000"
            }
            GradientStop {
                position: 0.5
                color: "#00000000"
            }
            GradientStop {
                position: 1.0
                color: "#26000000"
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.topMargin: topBar.barHeight
        onClicked: window.closePanel()
    }

    Bar.Top {
        id: topBar
        z: 20
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        windowWidth: window.width
        currentTime: window.currentTime
        activeSource: window.panelMode !== "" ? window.panelSource : ""
        onDesktopRequested: window.closePanel()
        onPanelRequested: (mode, anchorX, source) => window.togglePanel(mode, anchorX, source)
    }

    Panel.Root {
        z: 30
        anchors.top: parent.top
        anchors.topMargin: topBar.barHeight + 8
        x: Math.max(10, Math.min(window.width - width - 10, window.panelAnchorX - width / 2))
        mode: window.panelMode
        anchorX: window.panelAnchorX
        backdrop: wallpaper
        availableWidth: window.width
        availableHeight: window.height - topBar.barHeight
        onCloseRequested: window.closePanel()
        onModeRequested: mode => window.panelMode = mode

        Behavior on x {
            NumberAnimation {
                duration: 140
                easing.type: Easing.OutCubic
            }
        }
    }
}
