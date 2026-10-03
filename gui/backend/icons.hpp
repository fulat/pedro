#pragma once

#include <QFileInfo>
#include <QHash>
#include <QIcon>
#include <QJsonArray>
#include <QJsonDocument>
#include <QSettings>
#include <QUrl>
#include <QQuickImageProvider>
#include <QPainter>
#include <QSvgRenderer>

// Preserve the supplied icon's alpha mask while tinting it on every Qt backend.
class Icons final : public QQuickImageProvider {
    public:

        Icons() : QQuickImageProvider(QQuickImageProvider::Image) {
        }

        static void configureTheme() {
            auto paths = QIcon::themeSearchPaths();
            paths.prepend(QStringLiteral(":/pedro/appearance/icons"));
            paths.removeDuplicates();
            QIcon::setThemeSearchPaths(paths);
            const auto theme = qEnvironmentVariable("PEDRO_ICON_THEME");
            QIcon::setThemeName(theme.isEmpty() ? QStringLiteral("Pedro") : theme);
            QIcon::setFallbackThemeName(QStringLiteral("hicolor"));
        }

        QImage requestImage(const QString& id, QSize* size, const QSize& requested) override {
            if (id.startsWith("theme/")) {
                const auto names = QJsonDocument::fromJson(QUrl::fromPercentEncoding(id.mid(6).toUtf8()).toUtf8()).array();
                const auto target = (requested.isValid() ? requested : QSize(64, 64)).boundedTo(QSize(1024, 1024)).expandedTo(QSize(1, 1));
                const auto image = themedImage(names, target);
                if (size) {
                    *size = image.size();
                }
                return image;
            }
            const auto parts = id.split('/');

            if (parts.size() < 2 || id.contains("..")) {
                return {};
            }

            const auto asset = parts.mid(1).join('/');

            const auto directory = qEnvironmentVariable("PEDRO_QML_DIR");
            const auto base = directory.isEmpty() ? QString(":/qt/qml/gui") : directory;
            // The canonical Pedro logo is maintained at the asset root.
            const auto assetDirectory = asset == QStringLiteral("logo.svg") ? "/assets/" : "/assets/icons/";
            auto path = base + assetDirectory + asset;

            if (!QFileInfo(path).isFile() && parts[1].startsWith("window-")) {
                path = QStringLiteral(":/pedro/appearance/icons/Pedro/scalable/ui/") + parts[1];
            }
            const auto target = (requested.isValid() ? requested : QSize(64, 64)).boundedTo(QSize(1024, 1024)).expandedTo(QSize(1, 1));
            auto source = loadImage(path, target);

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

        static QImage loadImage(const QString& path, const QSize& target) {
            if (!QFileInfo(path).isFile()) {
                return {};
            }
            if (!path.endsWith(".svg", Qt::CaseInsensitive)) {
                return QImage(path);
            }
            QSvgRenderer renderer(path);
            if (!renderer.isValid()) {
                return {};
            }
            auto renderSize = renderer.defaultSize();
            renderSize.scale(target, Qt::KeepAspectRatio);
            QImage image(renderSize, QImage::Format_ARGB32_Premultiplied);
            image.fill(Qt::transparent);
            QPainter painter(&image);
            painter.setRenderHint(QPainter::Antialiasing, true);
            painter.setRenderHint(QPainter::SmoothPixmapTransform, true);
            renderer.render(&painter, image.rect());
            return image;
        }

        // Pedro's own SVGs use the existing renderer even without Qt's SVG icon plugin.
        // Directory names come from the theme's standard index, not MIME-specific mappings.
        static QImage pedroImage(const QString& name, const QSize& target) {
            for (const auto& root : QIcon::themeSearchPaths()) {
                const auto theme = root + "/Pedro/";
                if (!QFileInfo::exists(theme + "index.theme")) {
                    continue;
                }
                QSettings index(theme + "index.theme", QSettings::IniFormat);
                index.beginGroup("Icon Theme");
                const auto directories = index.value("Directories").toStringList();
                index.endGroup();
                for (const auto& directory : directories) {
                    if (index.value(directory + "/Context").toString() != "MimeTypes") {
                        continue;
                    }
                    const auto image = loadImage(theme + directory + '/' + name + ".svg", target);
                    if (!image.isNull()) {
                        return image;
                    }
                }
            }
            return {};
        }

        static QImage themedImage(const QJsonArray& candidates, const QSize& target) {
            for (const auto& candidate : candidates) {
                const auto name = candidate.toString();
                if (name.isEmpty() || name.contains('/') || name.contains('\\') || name.contains("..")) {
                    continue;
                }
                if (QIcon::themeName() == "Pedro") {
                    const auto own = pedroImage(name, target);
                    if (!own.isNull()) {
                        return own;
                    }
                }
                const auto pixmap = QIcon::fromTheme(name).pixmap(target);
                if (!pixmap.isNull()) {
                    return pixmap.toImage().convertToFormat(QImage::Format_ARGB32_Premultiplied);
                }
            }
            return pedroImage(QStringLiteral("text-x-generic"), target);
        }

        static QString themeIcon(const QString& fileName) {

            static const QHash<QString, QString> names = {
                {QStringLiteral("apps"), QStringLiteral("view-app-grid-symbolic")}, {QStringLiteral("browser"), QStringLiteral("web-browser-symbolic")}, {QStringLiteral("chat"), QStringLiteral("chat-message-new-symbolic")}, {QStringLiteral("folder"), QStringLiteral("folder-symbolic")}, {QStringLiteral("home"), QStringLiteral("go-home-symbolic")}, {QStringLiteral("music"), QStringLiteral("audio-x-generic-symbolic")}, {QStringLiteral("notes"), QStringLiteral("accessories-text-editor-symbolic")}, {QStringLiteral("photos"), QStringLiteral("image-x-generic-symbolic")}, {QStringLiteral("terminal"), QStringLiteral("utilities-terminal-symbolic")},
            };
            const auto name = QFileInfo(fileName).completeBaseName();

            return names.value(name, name);
        }
};
