import QtQuick


// Translates top-bar actions into panel requests from the shell view.
QtObject {
    required property var view

    // Maps an item's center into the bar before requesting its panel.
    function requestPanel(mode, sourceName, item) {
        const point = item.mapToItem(view, item.width / 2, item.height);
        view.panelRequested(mode, point.x, sourceName);
    }

}
