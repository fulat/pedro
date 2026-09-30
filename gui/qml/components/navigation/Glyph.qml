import QtQuick

// Declares the navigation glyph canvas while delegating painting to a controller.
Canvas {
    id: glyph

    required property var controller
    property string kind

    onKindChanged: requestPaint()
    onPaint: controller.paintNavigationGlyph(glyph)
}
