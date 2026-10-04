#ifndef PEDRO_PAPI_GUI_PREVIEW_MEDIA_PROVIDER_H
#define PEDRO_PAPI_GUI_PREVIEW_MEDIA_PROVIDER_H

#include <pedro/papi/gui/preview/provider.h>

#include <QTimer>

#include <memory>

namespace Pedro::Papi::Gui::Preview::Media {

    class Provider final : public Preview::Provider {
        public:

            explicit Provider(const QString& kind);

            ~Provider() override;

            void open(const QUrl& source) override;

            void close() override;

            void togglePlayback() override;

            void seek(qint64 position) override;

            void setVolume(qreal volume) override;

            void setMuted(bool muted) override;

        private:

            struct Data;

            void poll();

            std::unique_ptr<Data> data;

            QTimer timer;
    };

}

#endif
