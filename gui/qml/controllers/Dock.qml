import QtQuick

import "../scripts/theme.js" as Theme

// Owns procedural icon drawing used by the dock presentation.
QtObject {

    // Paints the code-editor mark on its icon canvas.
    function paintCode(canvas) {
        const context = canvas.getContext("2d");
        const scale = canvas.width / 56;

        context.clearRect(0, 0, canvas.width, canvas.height);
        context.save();
        context.scale(scale, scale);
        context.fillStyle = Theme.codeIconDark;
        context.beginPath();
        context.moveTo(36, 6);
        context.lineTo(48, 11);
        context.lineTo(48, 45);
        context.lineTo(36, 50);
        context.lineTo(17, 34);
        context.lineTo(8, 41);
        context.lineTo(3, 36);
        context.lineTo(13, 28);
        context.lineTo(3, 20);
        context.lineTo(8, 15);
        context.lineTo(17, 22);
        context.closePath();
        context.fill();
        context.fillStyle = Theme.codeIconBright;
        context.beginPath();
        context.moveTo(36, 14);
        context.lineTo(36, 42);
        context.lineTo(20, 28);
        context.closePath();
        context.fill();
        context.restore();
    }

    // Paints the music waves on their icon canvas.
    function paintMusic(canvas) {
        const context = canvas.getContext("2d");
        const scale = canvas.width / 56;

        context.clearRect(0, 0, canvas.width, canvas.height);
        context.save();
        context.scale(scale, scale);
        context.strokeStyle = Theme.musicIconStroke;
        context.lineCap = "round";

        for (let line = 0; line < 3; ++line) {
            context.lineWidth = 4 - line * 0.6;
            context.beginPath();
            context.moveTo(12 + line * 2, 20 + line * 8);
            context.quadraticCurveTo(28, 15 + line * 8, 44 - line * 2, 23 + line * 8);
            context.stroke();
        }

        context.restore();
    }
}
