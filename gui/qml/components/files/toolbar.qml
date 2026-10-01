pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

Item {
    implicitHeight: 55
    RowLayout {
        anchors.fill: parent
        spacing: 7
        Loader { source: "button.qml"; onLoaded: { item.text = Qt.binding(() => qsTranslate("Pedro", "files.browser.new")); item.symbol = "plus"; item.primary = true; item.arrow = true; } }
        Loader { source: "button.qml"; onLoaded: { item.text = Qt.binding(() => qsTranslate("Pedro", "files.sample.upload")); item.symbol = "upload"; } }
        Loader { source: "button.qml"; onLoaded: { item.text = Qt.binding(() => qsTranslate("Pedro", "files.browser.share")); item.symbol = "share"; } }
        Loader { source: "button.qml"; onLoaded: { item.text = Qt.binding(() => qsTranslate("Pedro", "files.browser.view")); item.symbol = "grid"; item.arrow = true; } }
        Item { Layout.fillWidth: true }
        Repeater {
            model: ["all", "folders", "documents", "images", "more"]
            delegate: Loader {
                id: filter
                required property string modelData
                source: "button.qml"
                onLoaded: {
                    item.text = Qt.binding(() => qsTranslate("Pedro", "files.browser." + filter.modelData));
                    item.primary = modelData === "all";
                    item.arrow = modelData === "more";
                    item.leftPadding = 8;
                    item.rightPadding = 8;
                    item.implicitWidth = Qt.binding(() => item.contentItem.implicitWidth + 16);
                    item.implicitHeight = 33;
                }
            }
        }
    }
}
