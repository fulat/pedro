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
        const QPointer<QQuickItem> item(source);
        if (!item || !item->window() || item->width() <= 0 || item->height() <= 0) {
            return {};
        }
        const auto ratio = item->window()->devicePixelRatio();
        const auto maximum = std::max(item->width(), item->height());
        const auto scale = std::min(140.0 / maximum, std::clamp(64.0 / maximum, 1.0, 2.0));
        const QSize size(std::ceil(item->width() * scale * ratio), std::ceil(item->height() * scale * ratio));
        const auto capture = item->grabToImage(size);
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
        if (!item || result.isNull()) {
            return {};
        }
        QPainter painter(&result);
        painter.setCompositionMode(QPainter::CompositionMode_DestinationIn);
        painter.fillRect(result.rect(), QColor(0, 0, 0, 220));
        painter.end();
        result.setDevicePixelRatio(ratio);
        return QPixmap::fromImage(result);
    }

}
