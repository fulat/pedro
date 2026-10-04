#pragma once

#include <QQuickAsyncImageProvider>
#include <QThreadPool>

namespace Pedro::Gui::Backend::Thumbnail {

    class Provider final : public QQuickAsyncImageProvider {
        public:

            Provider();

            QQuickImageResponse* requestImageResponse(const QString& id, const QSize& requestedSize) override;

        private:

            QThreadPool pool;
    };

}
