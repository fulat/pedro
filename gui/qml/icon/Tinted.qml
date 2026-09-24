pragma ComponentBehavior: Bound

import QtQuick
import "../logic/pixel.js" as Pixel
import "../logic/theme.js" as Theme

Item {
    id: root
    property url source
    property color tint: Theme.textPrimary
    readonly property real pixelRatio: Math.max(1, Screen.devicePixelRatio)
    implicitWidth: 24
    implicitHeight: 24

    Image {
        anchors.fill: parent
        source: root.source.toString().length
                ? "image://icons/" + root.tint.toString().replace("#", "") + "/"
                  + root.source.toString().split("/").pop() : ""
        sourceSize.width: Pixel.physical(root.width, root.pixelRatio)
        sourceSize.height: Pixel.physical(root.height, root.pixelRatio)
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: false
        antialiasing: true
    }
}
