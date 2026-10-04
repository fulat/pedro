#include <pedro/papi/io/thumbnail/image.h>

#include <QDateTime>
#include <QFile>
#include <QFileInfo>
#include <QMimeDatabase>
#include <QProcess>
#include <QResource>

#include <mutex>

// Qt static resource initialization must be declared in the global namespace.
static void initializeThumbnailResources() {

    Q_INIT_RESOURCE(pedro_thumbnail);
}

namespace Pedro::Papi::Io::Thumbnail {

    QImage image(const QUrl& source) {

        if (!source.isLocalFile()) {
            return {};
        }

        const QFileInfo file(source.toLocalFile());

        if (!file.isFile() || !file.isReadable()) {
            return {};
        }

        const auto mime = QMimeDatabase().mimeTypeForFile(file).name();

        if (!mime.startsWith(QStringLiteral("video/"))) {
            return {};
        }

        static std::once_flag initialized;
        std::call_once(initialized, initializeThumbnailResources);
        QFile script(QStringLiteral(":/pedro/papi/io/thumbnail/generate.py"));

        if (!script.open(QIODevice::ReadOnly)) {
            return {};
        }

        QProcess process;
        process.start(QStringLiteral("/usr/bin/python3"), {QStringLiteral("-c"), QString::fromUtf8(script.readAll()), source.toString(QUrl::FullyEncoded), mime, QString::number(file.lastModified().toSecsSinceEpoch())});

        if (!process.waitForFinished(15000)) {
            process.kill();
            process.waitForFinished();
            return {};
        }

        if (process.exitStatus() != QProcess::NormalExit || process.exitCode() != 0) {
            return {};
        }

        // GNOME validates URI and mtime and selects the registered decoder.
        return QImage(QString::fromUtf8(process.readAllStandardOutput()).trimmed());
    }

}
