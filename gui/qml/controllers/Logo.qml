import QtQuick

import "../scripts/theme.js" as Theme

// Translates top-bar actions into panel requests from the shell view.
QtObject {
    required property var view

    // Maps an item's center into the bar before requesting its panel.
    function requestPanel(mode, sourceName, item) {
        const point = item.mapToItem(view, item.width / 2, item.height);
        view.panelRequested(mode, point.x, sourceName);
    }

    // Paints the notification bell used by the status bar.
    function paintNotification(canvas) {
        const context = canvas.getContext("2d");
        context.clearRect(0, 0, canvas.width, canvas.height);
        context.fillStyle = Theme.white;
        context.beginPath();
        context.moveTo(4, 17);
        context.quadraticCurveTo(6, 15, 6, 10);
        context.quadraticCurveTo(6, 3, 10.5, 3);
        context.quadraticCurveTo(15, 3, 15, 10);
        context.quadraticCurveTo(15, 15, 17, 17);
        context.closePath();
        context.fill();
        context.beginPath();
        context.arc(10.5, 20, 2, 0, Math.PI * 2);
        context.fill();
    }
}
