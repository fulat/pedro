import QtQuick
import QtQuick.Shapes
import "palette.js" as Palette

Item {
    readonly property var colors: Palette.colors(Backend.appearanceMode)
    clip: true
    Rectangle { anchors.fill: parent; color: parent.colors.banner }
    Shape {
        width: 240
        height: 115
        transform: Scale { xScale: parent.width / 240; yScale: parent.height / 115 }
        ShapePath { strokeWidth: 0; fillColor: Palette.colors(Backend.appearanceMode).light ? "#eaf5ff" : "#405877"; PathSvg { path: "M0 40q35-30 65-7t70-4 70 10 35-9v30H0z" } }
        ShapePath { strokeWidth: 0; fillColor: "#8eb8df"; PathSvg { path: "m40 115 83-58 26 11 49-48 42-5v100z" } }
        ShapePath { strokeWidth: 0; fillColor: "#759ead"; PathSvg { path: "m74 115 79-38 31-17 32-18 24-15v88z" } }
        ShapePath { strokeWidth: 0; fillColor: "#c4bd93"; PathSvg { path: "m130 115 48-26 25-24 10 5 27-32v77z" } }
        ShapePath { strokeWidth: 0; fillColor: "#486c8c"; PathSvg { path: "m154 115 38-23 15 3 33-32v52z" } }
        ShapePath { strokeWidth: 0; fillColor: "#2c5f89"; PathSvg { path: "m183 115 57-27v27z" } }
    }
}
