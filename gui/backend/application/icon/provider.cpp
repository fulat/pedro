#include "provider.hpp"

#include <QDirIterator>
#include <QFileInfo>
#include <QIcon>
#include <QPixmap>
#include <QStandardPaths>
#include <QUrl>

namespace Pedro::Gui::Backend::Application::Icon {
    namespace {

        // Resolves application icons when no desktop platform theme is active.
        QIcon installedIcon(const QString& name) {

            const auto dataDirectories = QStandardPaths::standardLocations(QStandardPaths::GenericDataLocation);
            const QStringList extensions = {QStringLiteral("png"), QStringLiteral("svg"), QStringLiteral("xpm")};

            for (const auto& directory : dataDirectories) {
                for (const auto& extension : extensions) {
                    const auto path = QStringLiteral("%1/pixmaps/%2.%3").arg(directory, name, extension);

                    if (QFileInfo::exists(path)) {
                        return QIcon(path);
                    }
                }

                QDirIterator themed(QStringLiteral("%1/icons/hicolor").arg(directory), {QStringLiteral("%1.png").arg(name), QStringLiteral("%1.svg").arg(name), QStringLiteral("%1.xpm").arg(name)}, QDir::Files, QDirIterator::Subdirectories);

                if (themed.hasNext()) {
                    return QIcon(themed.next());
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
        auto icon = QFileInfo::exists(name) ? QIcon(name) : QIcon::fromTheme(name);

        if (icon.isNull()) {
            icon = installedIcon(name);
        }

        if (icon.isNull()) {
            return {};
        }

        const auto image = icon.pixmap(target).toImage();

        if (size) {
            *size = image.size();
        }

        return image;
    }

} // namespace Pedro::Gui::Backend::Application::Icon
