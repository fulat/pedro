import QtQuick
import ".." as Components

Components.Liquid {
    id: surface

    property Item sourceBackdrop
    // This wallpaper is owned by the surface and always shares its window.
    separateWindow: false
    backdrop: wallpaper

    Image {
        id: wallpaper
        width: surface.sourceBackdrop ? surface.sourceBackdrop.width : surface.width
        height: surface.sourceBackdrop ? surface.sourceBackdrop.height : surface.height
        source: surface.sourceBackdrop && surface.sourceBackdrop.source !== undefined
            ? surface.sourceBackdrop.source : Backend.wallpaper
        fillMode: Image.PreserveAspectCrop
        smooth: true
        mipmap: true
        visible: false
    }

    FrameAnimation {
        running: surface.visible && surface.sourceBackdrop !== null
        onTriggered: {
            const origin = surface.mapToItem(surface.sourceBackdrop, 0, 0);
            wallpaper.x = -Math.max(0, Math.min(origin.x, wallpaper.width - surface.width));
            wallpaper.y = -Math.max(0, Math.min(origin.y, wallpaper.height - surface.height));
        }
    }
}
