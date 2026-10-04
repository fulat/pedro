pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import ".." as Components
import "../icon" as Icon

Item {
    id: video
    objectName: "previewVideoOverlay"
    property var controller
    property Item backdrop
    readonly property var preview: controller ? controller.preview : null
    component Glass: Item {
        Components.Liquid {
            anchors.fill: parent
            backdrop: video.backdrop
            cornerRadius: 18
            frosted: false
            blurAmount: 0.35
            edgeColor: "#40ffffff"
        }
    }
    component Action: Controls.ToolButton {
        id: action
        property string symbol
        property string label
        implicitWidth: 36
        implicitHeight: 36
        padding: 9
        Accessible.name: label
        Controls.ToolTip.visible: hovered
        Controls.ToolTip.text: label
        contentItem: Icon.Tinted { source: action.symbol + ".svg"; tint: "white" }
        background: Rectangle { radius: 12; color: action.down ? "#40ffffff" : action.hovered ? "#20ffffff" : "transparent" }
    }
    component Slider: Controls.Slider {
        id: slider
        implicitHeight: 32
        background: Rectangle {
            x: slider.leftPadding
            y: (slider.height - height) / 2
            width: slider.availableWidth
            height: 4
            radius: 2
            color: "#55ffffff"
            Rectangle { width: parent.width * slider.visualPosition; height: parent.height; radius: 2; color: "#319cff" }
        }
        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: (slider.height - height) / 2
            width: 13; height: 13; radius: 7; color: "white"
        }
    }

    Glass {
        anchors.centerIn: parent
        width: 68; height: 68
        visible: video.preview && !video.preview.playing && !video.preview.busy
        Action {
            anchors.fill: parent
            padding: 21
            symbol: "play"
            label: qsTranslate("Pedro", "preview.play")
            onClicked: video.preview.togglePlayback()
        }
    }

    Glass {
        id: playback
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 16
        height: 54
        RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 8
            height: 38
            spacing: 8
            Action {
                symbol: video.preview && video.preview.playing ? "pause" : "play"
                label: qsTranslate("Pedro", video.preview && video.preview.playing ? "preview.pause" : "preview.play")
                enabled: video.preview && !video.preview.busy && !video.preview.error.length
                onClicked: video.preview.togglePlayback()
            }
            Action {
                visible: video.width > 420
                symbol: "backward"
                label: qsTranslate("Pedro", "preview.video.backward")
                enabled: video.preview && video.preview.seekable
                onClicked: video.preview.seek(Math.max(0, video.preview.position - 10000))
            }
            Action {
                visible: video.width > 420
                symbol: "advance"
                label: qsTranslate("Pedro", "preview.video.forward")
                enabled: video.preview && video.preview.seekable
                onClicked: video.preview.seek(Math.min(video.preview.duration, video.preview.position + 10000))
            }
            Controls.Label { visible: video.width > 340; text: video.preview ? video.controller.clock(video.preview.position) : "0:00"; color: "white"; font.pixelSize: 12 }
            Slider {
                Layout.fillWidth: true
                from: 0; to: video.preview ? Math.max(1, video.preview.duration) : 1
                value: video.preview ? video.preview.position : 0
                enabled: video.preview && video.preview.seekable
                Accessible.name: qsTranslate("Pedro", "preview.position")
                onMoved: video.preview.seek(value)
            }
            Controls.Label { visible: video.width > 340; text: video.preview ? video.controller.clock(video.preview.duration) : "0:00"; color: "white"; font.pixelSize: 12 }
            Action {
                visible: video.width > 260
                symbol: "speaker"
                opacity: video.preview && video.preview.muted ? 0.4 : 1
                label: qsTranslate("Pedro", "preview.mute")
                onClicked: video.preview.muted = !video.preview.muted
            }
            Slider {
                visible: video.width > 620
                Layout.preferredWidth: 80
                from: 0; to: 1
                value: video.preview ? video.preview.volume : 1
                Accessible.name: qsTranslate("Pedro", "preview.volume")
                onMoved: video.preview.volume = value
            }
            Action {
                visible: video.width > 200
                symbol: "fullscreen"
                label: qsTranslate("Pedro", "preview.video.fullscreen")
                onClicked: {
                    const window = video.Window.window;
                    if (window.visibility === Window.FullScreen) window.showNormal();
                    else window.showFullScreen();
                }
            }
        }
    }
}
