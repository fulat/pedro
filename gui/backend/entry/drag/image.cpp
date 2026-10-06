#include "image.h"

#include <QColor>
#include <QEventLoop>
#include <QImage>
#include <QPainter>
#include <QPointer>
#include <QQuickItem>
#include <QQuickItemGrabResult>
#include <QQuickWindow>
#include <QTimer>

#include <algorithm>
#include <cmath>

namespace Pedro::Gui::Backend::Entry::Drag {

    QPixmap image(QQuickItem* source) {
        const QPointer<QQuickItem> item(source ? source->findChild<QQuickItem*>(QStringLiteral("fileDragVisual")) : nullptr);
        const QPointer<QQuickItem> visual(item ? item.data() : source);
        if (!visual || !visual->window() || visual->width() <= 0 || visual->height() <= 0) {
            return {};
        }
        const auto ratio = visual->window()->devicePixelRatio();
        const auto maximum = std::max(visual->width(), visual->height());
        const auto scale = std::min(140.0 / maximum, std::clamp(64.0 / maximum, 1.0, 2.0));
        const QSize size(std::ceil(visual->width() * scale), std::ceil(visual->height() * scale));
        const auto capture = visual->grabToImage(size);
        if (!capture) {
            return {};
        }
        if (capture->image().isNull()) {
            // Bound the wait for Qt Quick's own capture before the native drag.
            // The event loop keeps input and rendering responsive during it.
            QEventLoop loop;
            QTimer deadline;
            deadline.setSingleShot(true);
            QObject::connect(capture.data(), &QQuickItemGrabResult::ready, &loop, &QEventLoop::quit);
            QObject::connect(&deadline, &QTimer::timeout, &loop, &QEventLoop::quit);
            deadline.start(80);
            loop.exec();
        }
        auto result = capture->image().convertToFormat(QImage::Format_ARGB32_Premultiplied);
        if (!visual)
            return {};
        bool painted = false;
        for (int y = 0; y < result.height() && !painted; ++y) {
            for (int x = 0; x < result.width(); ++x) {
                if (result.pixelColor(x, y).alpha() > 0) {
                    painted = true;
                    break;
                }
            }
        }
        if (!painted) {
            // Native Wayland can defer item readback. Capture the already
            // rendered window and crop its icon instead of starting invisibly.
            const auto window = visual->window();
            if (!window)
                return {};
            const auto frame = window->grabWindow();
            if (frame.isNull())
                return {};
            const auto position = visual->mapToScene(QPointF());
            const auto factor = frame.width() / qreal(window->width());
            const QRect crop(std::round(position.x() * factor), std::round(position.y() * factor), std::round(visual->width() * factor), std::round(visual->height() * factor));
            result = frame.copy(crop.intersected(frame.rect())).scaled(QSize(std::ceil(size.width() * ratio), std::ceil(size.height() * ratio)), Qt::KeepAspectRatio, Qt::SmoothTransformation).convertToFormat(QImage::Format_ARGB32_Premultiplied);
        }
        if (result.isNull())
            return {};
        QPainter painter(&result);
        painter.setCompositionMode(QPainter::CompositionMode_DestinationIn);
        painter.fillRect(result.rect(), QColor(0, 0, 0, 220));
        painter.end();
        result.setDevicePixelRatio(ratio);
        return QPixmap::fromImage(result);
    }

}
