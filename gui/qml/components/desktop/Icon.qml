import QtQuick

import "../../scripts/theme.js" as Theme
import "../icon" as Icon

// Draws the presentation-only icon for a desktop shortcut.
Item {
    id: desktopIcon

    readonly property bool thumbnailReady: thumbnail.status === Image.Ready
    property string kind
    property var iconNames: []
    property var revision: 0
    property url imageUrl
    property real cornerRadius: 6

    Image {
        visible: desktopIcon.kind === "document" || desktopIcon.kind === "notes" || desktopIcon.kind === "file" || desktopIcon.kind === "themed" || (desktopIcon.kind === "video" && !desktopIcon.thumbnailReady)
        anchors.fill: parent
        source: !visible ? "" : desktopIcon.kind !== "document" && desktopIcon.iconNames.length
            ? "image://icons/theme/" + encodeURIComponent(JSON.stringify(desktopIcon.iconNames))
            : "image://icons/original/document.svg"
        sourceSize: Qt.size(Math.ceil(desktopIcon.width * Math.max(1, Screen.devicePixelRatio) * 2),
            Math.ceil(desktopIcon.height * Math.max(1, Screen.devicePixelRatio) * 2))
        fillMode: Image.PreserveAspectFit
        smooth: true
        antialiasing: true
    }

    Rectangle {
        visible: desktopIcon.kind === "image" || (desktopIcon.kind === "video" && desktopIcon.thumbnailReady)
        anchors.centerIn: parent
        width: desktopIcon.width * 0.82
        height: desktopIcon.height * 0.68
        radius: 4
        color: Theme.imageIconFrame
        border.width: 2
        border.color: Theme.imageIconFrame
        clip: true

        Image {
            id: thumbnail
            anchors.fill: parent
            anchors.margins: 2
            source: desktopIcon.kind === "image" ? desktopIcon.imageUrl
                : desktopIcon.kind === "video" ? "image://thumbnails/" + encodeURIComponent(desktopIcon.imageUrl) + "?" + encodeURIComponent(String(desktopIcon.revision)) : ""
            asynchronous: true
            sourceSize: Qt.size(128, 96)
            fillMode: Image.PreserveAspectCrop
            smooth: true
            mipmap: true
        }
    }

    Rectangle {
        visible: desktopIcon.kind === "video" && thumbnail.status === Image.Ready
        anchors.centerIn: parent
        width: Math.min(34, desktopIcon.width * 0.46)
        height: width
        radius: width / 2
        color: "#b0202935"

        Icon.Tinted {
            anchors.centerIn: parent
            width: parent.width * 0.48
            height: width
            source: "../../../assets/icons/play.svg"
            tint: "white"
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
