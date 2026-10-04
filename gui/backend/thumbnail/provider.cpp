#include <pedro/papi/io/thumbnail/image.h>

#include "provider.h"

#include <QFutureWatcher>
#include <QQuickTextureFactory>
#include <QtConcurrentRun>

namespace Pedro::Gui::Backend::Thumbnail {

    class Response final : public QQuickImageResponse {
        public:

            Response(QThreadPool& pool, const QUrl& source) {

                connect(&watcher, &QFutureWatcher<QImage>::finished, this, [this] {
                    result = watcher.result();
                    emit finished();
                });
                watcher.setFuture(QtConcurrent::run(&pool, [source] { return Papi::Io::Thumbnail::image(source); }));
            }

            QQuickTextureFactory* textureFactory() const override {
                return QQuickTextureFactory::textureFactoryForImage(result);
            }

            QString errorString() const override {
                return result.isNull() ? QStringLiteral("Thumbnail unavailable") : QString{};
            }

        private:

            QFutureWatcher<QImage> watcher;

            QImage result;
    };

    Provider::Provider() {
        pool.setMaxThreadCount(2);
    }

    QQuickImageResponse* Provider::requestImageResponse(const QString& id, const QSize&) {
        return new Response(pool, QUrl(QUrl::fromPercentEncoding(id.section('?', 0, 0).toUtf8())));
    }

}
