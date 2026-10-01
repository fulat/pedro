import QtQuick
Rectangle {
    id: badge
    property string text
    property string tone: "work"
    implicitWidth: label.implicitWidth + 20
    implicitHeight: 25
    radius: 13
    color: tone === "design" ? "#efe1ff" : tone === "important" ? "#ffebce" : tone === "personal" ? "#ffe0ec" : "#d7fbdc"
    Text {
        id: label
        anchors.centerIn: parent
        text: badge.text
        color: badge.tone === "design" ? "#761cff" : badge.tone === "important" ? "#eb7600" : badge.tone === "personal" ? "#db4388" : "#159539"
        font.pixelSize: 11
    }
}
