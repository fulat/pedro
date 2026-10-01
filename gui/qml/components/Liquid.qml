import QtQuick
import QtQuick.Effects

import "../scripts/theme.js" as Theme

// Draws Pedro's clear glass from the real wallpaper behind it.
Item {
    id: liquid

    property Item backdrop
    property real cornerRadius: 16
    property bool frosted: false
    property point backdropOrigin: Qt.point(0, 0)

    // mapToItem does not notify bindings when a popup's ancestors move.
    // Track the actual position while visible, including popup reparenting.
    FrameAnimation {
        running: liquid.visible && liquid.backdrop !== null

        onTriggered: {
            const origin = liquid.mapToItem(liquid.backdrop, 0, 0);

            if (origin.x !== liquid.backdropOrigin.x || origin.y !== liquid.backdropOrigin.y) {
                liquid.backdropOrigin = origin;
            }
        }
    }

    ShaderEffectSource {
        id: backdropSample

        anchors.fill: parent
        sourceItem: liquid.backdrop
        sourceRect: {
            if (!liquid.backdrop) {
                return Qt.rect(0, 0, liquid.width, liquid.height);
            }

            return Qt.rect(liquid.backdropOrigin.x, liquid.backdropOrigin.y, liquid.width, liquid.height);
        }
        live: true
        recursive: false
        hideSource: false
        visible: false
    }

    Rectangle {
        id: glassMask

        anchors.fill: parent
        radius: liquid.cornerRadius
        color: Theme.white
        visible: false
        layer.enabled: true
        layer.smooth: true
        antialiasing: true
    }

    // Soften background details while preserving the wallpaper's light and color.
    MultiEffect {
        anchors.fill: parent
        source: backdropSample
        visible: liquid.backdrop !== null
        autoPaddingEnabled: false
        shadowEnabled: false
        blurEnabled: true
        blur: liquid.frosted ? 1.0 : Theme.menuBlur
        blurMax: liquid.frosted ? 64 : 32
        blurMultiplier: liquid.frosted ? 1.6 : 1.0
        saturation: liquid.frosted ? -0.30 : -0.08
        brightness: 0
        contrast: 0
        maskEnabled: true
        maskSource: glassMask
        maskThresholdMin: 0.25
        maskSpreadAtMin: 0.45
    }

    // A light tint separates controls without covering the background.
    Rectangle {
        anchors.fill: parent
        radius: liquid.cornerRadius
        color: liquid.frosted ? Theme.menuGlassHaze : Theme.liquidHaze
        border.width: 0
        antialiasing: true
    }
}
