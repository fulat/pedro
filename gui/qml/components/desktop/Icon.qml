import QtQuick

import "../../scripts/theme.js" as Theme

// Draws the presentation-only icon for a desktop shortcut.
Item {
    id: desktopIcon

    property string kind
    property url imageUrl
    property real cornerRadius: 6

    Image {
        visible: desktopIcon.kind === "notes" || desktopIcon.kind === "file"
        anchors.fill: parent
        source: "image://icons/original/document.svg"
        sourceSize: Qt.size(Math.ceil(desktopIcon.width * Math.max(1, Screen.devicePixelRatio) * 2),
            Math.ceil(desktopIcon.height * Math.max(1, Screen.devicePixelRatio) * 2))
        fillMode: Image.PreserveAspectFit
        smooth: true
        antialiasing: true
    }

    Rectangle {
        visible: desktopIcon.kind === "image"
        anchors.centerIn: parent
        width: desktopIcon.width * 0.82
        height: desktopIcon.height * 0.68
        radius: 4
        color: Theme.imageIconFrame
        border.width: 2
        border.color: Theme.imageIconFrame
        clip: true

        Image {
            anchors.fill: parent
            anchors.margins: 2
            source: desktopIcon.kind === "image" ? desktopIcon.imageUrl : ""
            asynchronous: true
            sourceSize: Qt.size(128, 96)
            fillMode: Image.PreserveAspectCrop
            smooth: true
            mipmap: true
        }
    }

    Rectangle {
        visible: desktopIcon.kind === "folder"
        x: desktopIcon.width * 0.12
        y: desktopIcon.height * 0.22
        width: desktopIcon.width * 0.48
        height: desktopIcon.height * 0.19
        radius: Math.min(5, desktopIcon.cornerRadius)
        color: Theme.folderTab
    }

    Rectangle {
        visible: desktopIcon.kind === "folder"
        anchors.horizontalCenter: parent.horizontalCenter
        y: desktopIcon.height * 0.32
        width: desktopIcon.width * 0.78
        height: desktopIcon.height * 0.52
        radius: desktopIcon.cornerRadius

        gradient: Gradient {
            GradientStop {
                position: 0
                color: Theme.folderTop
            }
            GradientStop {
                position: 1
                color: Theme.folderBottom
            }
        }
    }
}
