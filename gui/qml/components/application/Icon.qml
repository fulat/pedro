import QtQuick

// Draws a full-color application icon resolved by the native icon provider.
Image {
    id: icon

    required property string name

    source: name.length > 0 ? "image://applications/" + encodeURIComponent(name) : ""
    sourceSize: Qt.size(Math.max(1, width), Math.max(1, height))
    fillMode: Image.PreserveAspectFit
    asynchronous: true
    cache: true
    mipmap: true
    smooth: true
}
