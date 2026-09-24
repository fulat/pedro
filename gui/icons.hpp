#pragma once

#include <QQuickImageProvider>
#include <QPainter>
#include <QSvgRenderer>

// Preserve the supplied icon's alpha mask while tinting it on every Qt backend.
class Icons final : public QQuickImageProvider {
    public:

        Icons() : QQuickImageProvider(QQuickImageProvider::Image) {
        }
        QImage requestImage(const QString& id, QSize* size, const QSize& requested) override {
            const auto parts = id.split('/');
            if (parts.size() != 2 || parts[1].contains(".."))
                return {};
            const auto directory = qEnvironmentVariable("PEDRO_QML_DIR");
            const auto base = directory.isEmpty() ? QString(":/qt/qml/gui") : directory;
            const auto path = base + "/assets/icons/" + parts[1];
            const auto target = (requested.isValid() ? requested : QSize(64, 64)).boundedTo(QSize(1024, 1024)).expandedTo(QSize(1, 1));
            QImage source;

            if (parts[1].endsWith(".svg", Qt::CaseInsensitive)) {
                QSvgRenderer renderer(path);
                if (!renderer.isValid())
                    return {};

                auto renderSize = renderer.defaultSize();
                renderSize.scale(target, Qt::KeepAspectRatio);
                source = QImage(renderSize, QImage::Format_ARGB32_Premultiplied);
                source.fill(Qt::transparent);

                QPainter vectorPainter(&source);
                vectorPainter.setRenderHint(QPainter::Antialiasing, true);
                vectorPainter.setRenderHint(QPainter::SmoothPixmapTransform, true);
                renderer.render(&vectorPainter, source.rect());
            } else {
                source = QImage(path);
                if (source.isNull())
                    return {};

                source = source.scaled(target, Qt::KeepAspectRatio, Qt::SmoothTransformation).convertToFormat(QImage::Format_ARGB32_Premultiplied);
            }

            QPainter painter(&source);
            painter.setCompositionMode(QPainter::CompositionMode_SourceIn);
            painter.fillRect(source.rect(), QColor("#" + parts[0]));
            painter.end();
            if (size)
                *size = source.size();
            return source;
        }
};
