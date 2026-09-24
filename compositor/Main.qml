import QtQuick
import QtWayland.Compositor
import QtWayland.Compositor.XdgShell

WaylandCompositor {
    socketName: "wayland-0"
    XdgShell {
        onToplevelCreated: (toplevel, xdgSurface) => {
            let item = clientView.createObject(outputWindow.contentItem,
                                               { "shellSurface": xdgSurface });
            item.takeFocus();
        }
    }
    WaylandOutput {
        sizeFollowsWindow: true
        window: Window {
            id: outputWindow
            width: 1024
            height: 768
            // C++ connects readiness before showing this window.
            visible: false
            color: "#1f1f1f"
            title: "Pedro compositor"
        }
    }
    Component {
        id: clientView
        ShellSurfaceItem {
            autoCreatePopupItems: true
            onSurfaceDestroyed: destroy()
        }
    }
}
