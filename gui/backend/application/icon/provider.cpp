#include "provider.hpp"

#include <QDirIterator>
#include <QFileInfo>
#include <QIcon>
#include <QPixmap>
#include <QPainter>
#include <QSvgRenderer>
#include <QStandardPaths>
#include <QUrl>

namespace Pedro::Gui::Backend::Application::Icon {
    namespace {

        QImage renderFile(const QString& path, const QSize& target) {

            if (path.endsWith(QStringLiteral(".svg"), Qt::CaseInsensitive)) {
                QSvgRenderer renderer(path);
                if (!renderer.isValid()) {
                    return {};
                }
                QImage image(target, QImage::Format_ARGB32_Premultiplied);
                image.fill(Qt::transparent);
                QPainter painter(&image);
                renderer.render(&painter);
                return image;
            }
            return QIcon(path).pixmap(target).toImage();
        }

        // Resolves application icons when no desktop platform theme is active.
        QString installedPath(const QString& name) {

            const auto dataDirectories = QStandardPaths::standardLocations(QStandardPaths::GenericDataLocation);
            const QStringList extensions = {QStringLiteral("png"), QStringLiteral("svg"), QStringLiteral("xpm")};

            for (const auto& directory : dataDirectories) {
                for (const auto& extension : extensions) {
                    const auto path = QStringLiteral("%1/pixmaps/%2.%3").arg(directory, name, extension);

                    if (QFileInfo::exists(path)) {
                        return path;
                    }
                }

                QDirIterator themed(QStringLiteral("%1/icons/hicolor").arg(directory), {QStringLiteral("%1.png").arg(name), QStringLiteral("%1.svg").arg(name), QStringLiteral("%1.xpm").arg(name)}, QDir::Files, QDirIterator::Subdirectories);

                if (themed.hasNext()) {
                    return themed.next();
                }
            }

            return {};
        }

    } // namespace

    Provider::Provider() : QQuickImageProvider(QQuickImageProvider::Image) {
    }

    QImage Provider::requestImage(const QString& id, QSize* size, const QSize& requestedSize) {

        const auto name = QUrl::fromPercentEncoding(id.toUtf8());
        const auto target = (requestedSize.isValid() ? requestedSize : QSize(64, 64)).boundedTo(QSize(1024, 1024)).expandedTo(QSize(1, 1));
        auto image = QFileInfo::exists(name) ? renderFile(name, target) : QIcon::fromTheme(name).pixmap(target).toImage();

        // Some inherited icon engines advertise an icon but return a null
        // pixmap. Native Qt SVG rendering can still load the installed file.
        if (image.isNull()) {
            image = renderFile(installedPath(name), target);
        }
        if (image.isNull()) {
            image = QIcon::fromTheme(QStringLiteral("application-x-executable")).pixmap(target).toImage();
        }
        if (image.isNull()) {
            image = renderFile(QStringLiteral(":/qt/qml/gui/assets/icons/window.svg"), target);
        }

        if (size) {
            *size = image.size();
        }

        return image;
    }

} // namespace Pedro::Gui::Backend::Application::Icon
