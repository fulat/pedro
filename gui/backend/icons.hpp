#pragma once

#include <QFileInfo>
#include <QHash>
#include <QIcon>
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

            if (parts.size() != 2 || parts[1].contains("..")) {
                return {};
            }

            const auto directory = qEnvironmentVariable("PEDRO_QML_DIR");
            const auto base = directory.isEmpty() ? QString(":/qt/qml/gui") : directory;
            // The canonical Pedro logo is maintained at the asset root.
            const auto assetDirectory = parts[1] == QStringLiteral("logo.svg") ? "/assets/" : "/assets/icons/";
            auto path = base + assetDirectory + parts[1];

            if (!QFileInfo(path).isFile() && parts[1].startsWith("window-")) {
                path = QStringLiteral(":/pedro/appearance/icons/Pedro/scalable/ui/") + parts[1];
            }
            const auto target = (requested.isValid() ? requested : QSize(64, 64)).boundedTo(QSize(1024, 1024)).expandedTo(QSize(1, 1));
            QImage source;

            if (parts[1].endsWith(".svg", Qt::CaseInsensitive) && QFileInfo(path).isFile()) {
                QSvgRenderer renderer(path);

                if (renderer.isValid()) {
                    auto renderSize = renderer.defaultSize();
                    renderSize.scale(target, Qt::KeepAspectRatio);
                    source = QImage(renderSize, QImage::Format_ARGB32_Premultiplied);
                    source.fill(Qt::transparent);

                    QPainter vectorPainter(&source);
                    vectorPainter.setRenderHint(QPainter::Antialiasing, true);
                    vectorPainter.setRenderHint(QPainter::SmoothPixmapTransform, true);
                    renderer.render(&vectorPainter, source.rect());
                }
            } else if (QFileInfo(path).isFile()) {
                source = QImage(path);
            }

            if (source.isNull()) {
                const auto icon = QIcon::fromTheme(themeIcon(parts[1]));

                if (!icon.isNull()) {
                    source = icon.pixmap(target).toImage().convertToFormat(QImage::Format_ARGB32_Premultiplied);
                }
            }

            if (source.isNull()) {
                return {};
            }

            if (source.size() != target) {
                source = source.scaled(target, Qt::KeepAspectRatio, Qt::SmoothTransformation).convertToFormat(QImage::Format_ARGB32_Premultiplied);
            }

            if (parts[0] != "original") {
                QPainter painter(&source);
                painter.setCompositionMode(QPainter::CompositionMode_SourceIn);
                painter.fillRect(source.rect(), QColor("#" + parts[0]));
                painter.end();
            }

            if (size) {
                *size = source.size();
            }

            return source;
        }

    private:

        static QString themeIcon(const QString& fileName) {

            static const QHash<QString, QString> names = {
                {QStringLiteral("apps"), QStringLiteral("view-app-grid-symbolic")}, {QStringLiteral("browser"), QStringLiteral("web-browser-symbolic")}, {QStringLiteral("chat"), QStringLiteral("chat-message-new-symbolic")}, {QStringLiteral("folder"), QStringLiteral("folder-symbolic")}, {QStringLiteral("home"), QStringLiteral("go-home-symbolic")}, {QStringLiteral("music"), QStringLiteral("audio-x-generic-symbolic")}, {QStringLiteral("notes"), QStringLiteral("accessories-text-editor-symbolic")}, {QStringLiteral("photos"), QStringLiteral("image-x-generic-symbolic")}, {QStringLiteral("terminal"), QStringLiteral("utilities-terminal-symbolic")},
            };
            const auto name = QFileInfo(fileName).completeBaseName();

            return names.value(name, name);
        }
};
