pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Controls.Basic as Controls
import "../../scripts/theme.js" as Theme

Item {
    id: name
    property var behavior: ({renaming: false, label: "", textColor: "white", cutPending: false, nameSize: 12, nameWeight: Font.Medium, nameAlignment: Text.AlignHCenter})
    readonly property var editor: input
    property string appearanceMode: Backend.appearanceMode
    readonly property bool light: appearanceMode === "light"
    readonly property color editorInk: light ? "#263b63" : "#e3ebf8"
    readonly property bool brightLabel: label.color.r * 0.2126 + label.color.g * 0.7152 + label.color.b * 0.0722 > 0.55
    Item {
        id: display
        anchors.fill: parent
        visible: !name.behavior.renaming
        opacity: name.behavior.cutPending ? Theme.cutOpacity : 1
        Rectangle {
            id: shadowSurface
            width: Math.min(display.width, label.contentWidth)
            height: label.contentHeight
            x: label.horizontalAlignment === Text.AlignLeft ? 0
                : label.horizontalAlignment === Text.AlignRight ? display.width - width
                : (display.width - width) / 2
            y: (display.height - height) / 2
            radius: 8
            color: "#66000000"
            visible: false
            layer.enabled: name.brightLabel
        }
        MultiEffect {
            anchors.fill: shadowSurface
            source: shadowSurface
            visible: name.brightLabel
            blurEnabled: true
            blurMax: 12
            blur: 1.0
            autoPaddingEnabled: true
        }
        Text {
            id: label
            objectName: "entryNameLabel"
            anchors.fill: parent
            text: Backend.elideEntryName(name.behavior.label, font, width, 2, !name.behavior.folder)
            color: name.behavior.textColor
            font.pixelSize: name.behavior.nameSize
            font.weight: name.behavior.nameWeight
            horizontalAlignment: name.behavior.nameAlignment
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.Wrap
            maximumLineCount: 2
            textFormat: Text.PlainText
        }
    }
    Controls.TextField {
        id: input
        objectName: "entryNameEditor"
        anchors.fill: parent
        visible: name.behavior.renaming
        color: name.editorInk
        font.pixelSize: name.behavior.nameSize
        font.weight: name.behavior.nameWeight
        horizontalAlignment: name.behavior.nameAlignment
        selectionColor: name.light ? "#405785bf" : "#555b91d1"
        selectedTextColor: name.editorInk
        padding: 3
        background: Rectangle {
            radius: 5
            color: name.light ? "#cce8eef7" : "#a3232e3c"
            border.color: Backend.fileTransfer.validName(input.text) ? Theme.liquidEdge : "#ef7777"
        }
        onAccepted: name.behavior.finishRename()
        onActiveFocusChanged: {
            if (!activeFocus && name.behavior.renaming) name.behavior.finishRename(false);
        }
        Keys.onEscapePressed: name.behavior.cancelRename()
    }
}
