#include "feedback.h"

#include <QCoreApplication>
#include <QDrag>
#include <QEvent>
#include <QGuiApplication>
#include <QPaintDeviceWindow>
#include <QTimer>

namespace Pedro::Gui::Backend::Entry::Drag {

    void prepareFeedback(QDrag* drag) {
        if (!drag || !QGuiApplication::platformName().startsWith(QStringLiteral("wayland"))) {
            return;
        }
        const auto previous = QGuiApplication::allWindows();
        QTimer::singleShot(0, drag, [previous] {
            const auto flags = Qt::BypassWindowManagerHint | Qt::WindowTransparentForInput | Qt::WindowDoesNotAcceptFocus;
            for (auto* window : QGuiApplication::allWindows()) {
                if (previous.contains(window) || (window->flags() & flags) != flags) {
                    continue;
                }
                if (auto* raster = qobject_cast<QPaintDeviceWindow*>(window)) {
                    // Qt's native drag icon may paint before Wayland assigns
                    // its drag role. Repaint after start_drag so the buffer and
                    // hotspot offset are committed with that role in place.
                    // A scheduled update alone can wait for an unmapped frame.
                    raster->update();
                    QEvent update(QEvent::UpdateRequest);
                    QCoreApplication::sendEvent(raster, &update);
                }
            }
        });
    }

}
