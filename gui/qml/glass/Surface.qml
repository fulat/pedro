pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

Item {
    id: root

    property Item backdrop

    property real radius: 16
    property bool pointerVisible: false
    property real pointerX: width / 2

    readonly property real pointerHeight: 10
    readonly property real pointerHalfWidth: 11

    // Smoother joins so the arrow feels molded into the frame.
    readonly property real pointerJoinRadius: 3.6
    readonly property real pointerApexRadius: 2.0

    readonly property real resolvedPointerX: Math.max(
        root.radius + 14,
        Math.min(root.width - root.radius - 14, root.pointerX)
    )

    readonly property real pointerLeftX: root.resolvedPointerX - root.pointerHalfWidth
    readonly property real pointerRightX: root.resolvedPointerX + root.pointerHalfWidth

    property color tint: Qt.rgba(0.02, 0.05, 0.10, 0.40)
    property color stroke: Qt.rgba(0.455, 0.545, 0.659, 0.32)
    property color highlight: Qt.rgba(0.549, 0.663, 0.780, 0.18)

    ShaderEffectSource {
        id: sample

        x: 0
        y: -root.pointerHeight
        width: root.width
        height: root.height + root.pointerHeight

        sourceItem: root.backdrop

        sourceRect: {
            if (!root.backdrop)
                return Qt.rect(0, 0, root.width, root.height + root.pointerHeight)

            const p = root.mapToItem(root.backdrop, 0, -root.pointerHeight)

            return Qt.rect(
                p.x,
                p.y,
                root.width,
                root.height + root.pointerHeight
            )
        }

        live: true
        recursive: false
        hideSource: false
        visible: false
    }

    // Unified silhouette mask: pointer + body = one shape.
    Shape {
        id: mask

        x: 0
        y: -root.pointerHeight
        width: root.width
        height: root.height + root.pointerHeight

        visible: false
        layer.enabled: true
        layer.smooth: true
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 0
            fillColor: "white"

            startX: root.radius
            startY: root.pointerHeight

            PathLine {
                x: root.pointerVisible
                   ? root.pointerLeftX - root.pointerJoinRadius
                   : root.width - root.radius
                y: root.pointerHeight
            }

            PathQuad {
                controlX: root.pointerVisible
                          ? root.pointerLeftX
                          : root.width - root.radius
                controlY: root.pointerHeight

                x: root.pointerVisible
                   ? root.pointerLeftX + root.pointerJoinRadius * 0.6
                   : root.width - root.radius
                y: root.pointerVisible
                   ? root.pointerHeight - root.pointerJoinRadius * 0.78
                   : root.pointerHeight
            }

            PathLine {
                x: root.pointerVisible
                   ? root.resolvedPointerX - root.pointerApexRadius
                   : root.width - root.radius
                y: root.pointerVisible
                   ? root.pointerApexRadius
                   : root.pointerHeight
            }

            PathQuad {
                controlX: root.pointerVisible
                          ? root.resolvedPointerX
                          : root.width - root.radius
                controlY: root.pointerVisible ? 0 : root.pointerHeight

                x: root.pointerVisible
                   ? root.resolvedPointerX + root.pointerApexRadius
                   : root.width - root.radius
                y: root.pointerVisible
                   ? root.pointerApexRadius
                   : root.pointerHeight
            }

            PathLine {
                x: root.pointerVisible
                   ? root.pointerRightX - root.pointerJoinRadius * 0.6
                   : root.width - root.radius
                y: root.pointerVisible
                   ? root.pointerHeight - root.pointerJoinRadius * 0.78
                   : root.pointerHeight
            }

            PathQuad {
                controlX: root.pointerVisible
                          ? root.pointerRightX
                          : root.width - root.radius
                controlY: root.pointerHeight

                x: root.pointerVisible
                   ? root.pointerRightX + root.pointerJoinRadius
                   : root.width - root.radius
                y: root.pointerHeight
            }

            PathLine { x: root.width - root.radius; y: root.pointerHeight }

            PathQuad {
                controlX: root.width
                controlY: root.pointerHeight
                x: root.width
                y: root.pointerHeight + root.radius
            }

            PathLine { x: root.width; y: root.height + root.pointerHeight - root.radius }

            PathQuad {
                controlX: root.width
                controlY: root.height + root.pointerHeight
                x: root.width - root.radius
                y: root.height + root.pointerHeight
            }

            PathLine { x: root.radius; y: root.height + root.pointerHeight }

            PathQuad {
                controlX: 0
                controlY: root.height + root.pointerHeight
                x: 0
                y: root.height + root.pointerHeight - root.radius
            }

            PathLine { x: 0; y: root.pointerHeight + root.radius }

            PathQuad {
                controlX: 0
                controlY: root.pointerHeight
                x: root.radius
                y: root.pointerHeight
            }
        }
    }

    MultiEffect {
        x: 0
        y: -root.pointerHeight
        width: root.width
        height: root.height + root.pointerHeight

        source: sample
        autoPaddingEnabled: false

        blurEnabled: true
        blur: 0.76
        blurMax: 64
        blurMultiplier: 1.0

        saturation: -0.08
        brightness: -0.08
        contrast: 0.10

        colorization: 0.12
        colorizationColor: Qt.rgba(0.027, 0.102, 0.196, 1.0)

        maskEnabled: true
        maskSource: mask

        maskThresholdMin: 0.25
        maskSpreadAtMin: 0.45
    }

    Shape {
        id: surface

        x: 0
        y: -root.pointerHeight
        width: root.width
        height: root.height + root.pointerHeight

        layer.enabled: true
        layer.smooth: true
        preferredRendererType: Shape.CurveRenderer

        // Base fill
        ShapePath {
            strokeWidth: 0
            fillColor: root.tint

            startX: root.radius
            startY: root.pointerHeight

            PathLine {
                x: root.pointerVisible
                   ? root.pointerLeftX - root.pointerJoinRadius
                   : root.width - root.radius
                y: root.pointerHeight
            }

            PathQuad {
                controlX: root.pointerVisible
                          ? root.pointerLeftX
                          : root.width - root.radius
                controlY: root.pointerHeight

                x: root.pointerVisible
                   ? root.pointerLeftX + root.pointerJoinRadius * 0.6
                   : root.width - root.radius
                y: root.pointerVisible
                   ? root.pointerHeight - root.pointerJoinRadius * 0.78
                   : root.pointerHeight
            }

            PathLine {
                x: root.pointerVisible
                   ? root.resolvedPointerX - root.pointerApexRadius
                   : root.width - root.radius
                y: root.pointerVisible
                   ? root.pointerApexRadius
                   : root.pointerHeight
            }

            PathQuad {
                controlX: root.pointerVisible
                          ? root.resolvedPointerX
                          : root.width - root.radius
                controlY: root.pointerVisible ? 0 : root.pointerHeight

                x: root.pointerVisible
                   ? root.resolvedPointerX + root.pointerApexRadius
                   : root.width - root.radius
                y: root.pointerVisible
                   ? root.pointerApexRadius
                   : root.pointerHeight
            }

            PathLine {
                x: root.pointerVisible
                   ? root.pointerRightX - root.pointerJoinRadius * 0.6
                   : root.width - root.radius
                y: root.pointerVisible
                   ? root.pointerHeight - root.pointerJoinRadius * 0.78
                   : root.pointerHeight
            }

            PathQuad {
                controlX: root.pointerVisible
                          ? root.pointerRightX
                          : root.width - root.radius
                controlY: root.pointerHeight

                x: root.pointerVisible
                   ? root.pointerRightX + root.pointerJoinRadius
                   : root.width - root.radius
                y: root.pointerHeight
            }

            PathLine { x: root.width - root.radius; y: root.pointerHeight }

            PathQuad {
                controlX: root.width
                controlY: root.pointerHeight
                x: root.width
                y: root.pointerHeight + root.radius
            }

            PathLine { x: root.width; y: root.height + root.pointerHeight - root.radius }

            PathQuad {
                controlX: root.width
                controlY: root.height + root.pointerHeight
                x: root.width - root.radius
                y: root.height + root.pointerHeight
            }

            PathLine { x: root.radius; y: root.height + root.pointerHeight }

            PathQuad {
                controlX: 0
                controlY: root.height + root.pointerHeight
                x: 0
                y: root.height + root.pointerHeight - root.radius
            }

            PathLine { x: 0; y: root.pointerHeight + root.radius }

            PathQuad {
                controlX: 0
                controlY: root.pointerHeight
                x: root.radius
                y: root.pointerHeight
            }
        }

        // Continuous vertical glass gradient
        ShapePath {
            strokeWidth: 0

            fillGradient: LinearGradient {
                x1: 0
                y1: 0
                x2: 0
                y2: surface.height

                GradientStop { position: 0.0; color: Qt.rgba(0.114, 0.208, 0.318, 0.135) }
                GradientStop { position: 0.22; color: Qt.rgba(0.094, 0.173, 0.271, 0.082) }
                GradientStop { position: 0.55; color: Qt.rgba(0.051, 0.110, 0.192, 0.058) }
                GradientStop { position: 0.82; color: Qt.rgba(0.027, 0.063, 0.122, 0.090) }
                GradientStop { position: 1.0; color: Qt.rgba(0.012, 0.031, 0.067, 0.155) }
            }

            startX: root.radius
            startY: root.pointerHeight

            PathLine {
                x: root.pointerVisible
                   ? root.pointerLeftX - root.pointerJoinRadius
                   : root.width - root.radius
                y: root.pointerHeight
            }

            PathQuad {
                controlX: root.pointerVisible
                          ? root.pointerLeftX
                          : root.width - root.radius
                controlY: root.pointerHeight

                x: root.pointerVisible
                   ? root.pointerLeftX + root.pointerJoinRadius * 0.6
                   : root.width - root.radius
                y: root.pointerVisible
                   ? root.pointerHeight - root.pointerJoinRadius * 0.78
                   : root.pointerHeight
            }

            PathLine {
                x: root.pointerVisible
                   ? root.resolvedPointerX - root.pointerApexRadius
                   : root.width - root.radius
                y: root.pointerVisible
                   ? root.pointerApexRadius
                   : root.pointerHeight
            }

            PathQuad {
                controlX: root.pointerVisible
                          ? root.resolvedPointerX
                          : root.width - root.radius
                controlY: root.pointerVisible ? 0 : root.pointerHeight

                x: root.pointerVisible
                   ? root.resolvedPointerX + root.pointerApexRadius
                   : root.width - root.radius
                y: root.pointerVisible
                   ? root.pointerApexRadius
                   : root.pointerHeight
            }

            PathLine {
                x: root.pointerVisible
                   ? root.pointerRightX - root.pointerJoinRadius * 0.6
                   : root.width - root.radius
                y: root.pointerVisible
                   ? root.pointerHeight - root.pointerJoinRadius * 0.78
                   : root.pointerHeight
            }

            PathQuad {
                controlX: root.pointerVisible
                          ? root.pointerRightX
                          : root.width - root.radius
                controlY: root.pointerHeight

                x: root.pointerVisible
                   ? root.pointerRightX + root.pointerJoinRadius
                   : root.width - root.radius
                y: root.pointerHeight
            }

            PathLine { x: root.width - root.radius; y: root.pointerHeight }

            PathQuad {
                controlX: root.width
                controlY: root.pointerHeight
                x: root.width
                y: root.pointerHeight + root.radius
            }

            PathLine { x: root.width; y: root.height + root.pointerHeight - root.radius }

            PathQuad {
                controlX: root.width
                controlY: root.height + root.pointerHeight
                x: root.width - root.radius
                y: root.height + root.pointerHeight
            }

            PathLine { x: root.radius; y: root.height + root.pointerHeight }

            PathQuad {
                controlX: 0
                controlY: root.height + root.pointerHeight
                x: 0
                y: root.height + root.pointerHeight - root.radius
            }

            PathLine { x: 0; y: root.pointerHeight + root.radius }

            PathQuad {
                controlX: 0
                controlY: root.pointerHeight
                x: root.radius
                y: root.pointerHeight
            }
        }

        // Soft top glow wash (fill-based, not a thin 1px line)
        ShapePath {
            strokeWidth: 0

            fillGradient: LinearGradient {
                x1: 0
                y1: 0
                x2: 0
                y2: root.height * 0.34

                GradientStop { position: 0.0; color: Qt.rgba(0.467, 0.600, 0.729, 0.11) }
                GradientStop { position: 0.40; color: Qt.rgba(0.278, 0.420, 0.569, 0.045) }
                GradientStop { position: 1.0; color: Qt.rgba(0.0, 0.0, 0.0, 0.0) }
            }

            startX: root.radius
            startY: root.pointerHeight

            PathLine {
                x: root.pointerVisible
                   ? root.pointerLeftX - root.pointerJoinRadius
                   : root.width - root.radius
                y: root.pointerHeight
            }

            PathQuad {
                controlX: root.pointerVisible
                          ? root.pointerLeftX
                          : root.width - root.radius
                controlY: root.pointerHeight

                x: root.pointerVisible
                   ? root.pointerLeftX + root.pointerJoinRadius * 0.6
                   : root.width - root.radius
                y: root.pointerVisible
                   ? root.pointerHeight - root.pointerJoinRadius * 0.78
                   : root.pointerHeight
            }

            PathLine {
                x: root.pointerVisible
                   ? root.resolvedPointerX - root.pointerApexRadius
                   : root.width - root.radius
                y: root.pointerVisible
                   ? root.pointerApexRadius
                   : root.pointerHeight
            }

            PathQuad {
                controlX: root.pointerVisible
                          ? root.resolvedPointerX
                          : root.width - root.radius
                controlY: root.pointerVisible ? 0 : root.pointerHeight

                x: root.pointerVisible
                   ? root.resolvedPointerX + root.pointerApexRadius
                   : root.width - root.radius
                y: root.pointerVisible
                   ? root.pointerApexRadius
                   : root.pointerHeight
            }

            PathLine {
                x: root.pointerVisible
                   ? root.pointerRightX - root.pointerJoinRadius * 0.6
                   : root.width - root.radius
                y: root.pointerVisible
                   ? root.pointerHeight - root.pointerJoinRadius * 0.78
                   : root.pointerHeight
            }

            PathQuad {
                controlX: root.pointerVisible
                          ? root.pointerRightX
                          : root.width - root.radius
                controlY: root.pointerHeight

                x: root.pointerVisible
                   ? root.pointerRightX + root.pointerJoinRadius
                   : root.width - root.radius
                y: root.pointerHeight
            }

            PathLine { x: root.width - root.radius; y: root.pointerHeight }

            PathQuad {
                controlX: root.width
                controlY: root.pointerHeight
                x: root.width
                y: root.pointerHeight + root.radius
            }

            PathLine { x: root.width; y: root.height * 0.36 }

            PathLine { x: 0; y: root.height * 0.36 }

            PathLine { x: 0; y: root.pointerHeight + root.radius }

            PathQuad {
                controlX: 0
                controlY: root.pointerHeight
                x: root.radius
                y: root.pointerHeight
            }
        }

        // Single outer border, softened
        ShapePath {
            strokeWidth: 1.15
            strokeColor: root.stroke
            fillColor: "transparent"

            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.RoundCap

            startX: root.radius
            startY: root.pointerHeight

            PathLine {
                x: root.pointerVisible
                   ? root.pointerLeftX - root.pointerJoinRadius
                   : root.width - root.radius
                y: root.pointerHeight
            }

            PathQuad {
                controlX: root.pointerVisible
                          ? root.pointerLeftX
                          : root.width - root.radius
                controlY: root.pointerHeight

                x: root.pointerVisible
                   ? root.pointerLeftX + root.pointerJoinRadius * 0.6
                   : root.width - root.radius
                y: root.pointerVisible
                   ? root.pointerHeight - root.pointerJoinRadius * 0.78
                   : root.pointerHeight
            }

            PathLine {
                x: root.pointerVisible
                   ? root.resolvedPointerX - root.pointerApexRadius
                   : root.width - root.radius
                y: root.pointerVisible
                   ? root.pointerApexRadius
                   : root.pointerHeight
            }

            PathQuad {
                controlX: root.pointerVisible
                          ? root.resolvedPointerX
                          : root.width - root.radius
                controlY: root.pointerVisible ? 0 : root.pointerHeight

                x: root.pointerVisible
                   ? root.resolvedPointerX + root.pointerApexRadius
                   : root.width - root.radius
                y: root.pointerVisible
                   ? root.pointerApexRadius
                   : root.pointerHeight
            }

            PathLine {
                x: root.pointerVisible
                   ? root.pointerRightX - root.pointerJoinRadius * 0.6
                   : root.width - root.radius
                y: root.pointerVisible
                   ? root.pointerHeight - root.pointerJoinRadius * 0.78
                   : root.pointerHeight
            }

            PathQuad {
                controlX: root.pointerVisible
                          ? root.pointerRightX
                          : root.width - root.radius
                controlY: root.pointerHeight

                x: root.pointerVisible
                   ? root.pointerRightX + root.pointerJoinRadius
                   : root.width - root.radius
                y: root.pointerHeight
            }

            PathLine { x: root.width - root.radius; y: root.pointerHeight }

            PathQuad {
                controlX: root.width
                controlY: root.pointerHeight
                x: root.width
                y: root.pointerHeight + root.radius
            }

            PathLine { x: root.width; y: root.height + root.pointerHeight - root.radius }

            PathQuad {
                controlX: root.width
                controlY: root.height + root.pointerHeight
                x: root.width - root.radius
                y: root.height + root.pointerHeight
            }

            PathLine { x: root.radius; y: root.height + root.pointerHeight }

            PathQuad {
                controlX: 0
                controlY: root.height + root.pointerHeight
                x: 0
                y: root.height + root.pointerHeight - root.radius
            }

            PathLine { x: 0; y: root.pointerHeight + root.radius }

            PathQuad {
                controlX: 0
                controlY: root.pointerHeight
                x: root.radius
                y: root.pointerHeight
            }
        }
    }
}
