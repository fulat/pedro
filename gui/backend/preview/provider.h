#pragma once

#include <QQuickImageProvider>

namespace Pedro::Papi::Gui::Preview {
    class Manager;
}

namespace Pedro::Gui::Backend::Preview {

    class Provider final : public QQuickImageProvider {
        public:

            explicit Provider(Papi::Gui::Preview::Manager& manager);

            explicit Provider(QObject& owner);

            QImage requestImage(const QString& id, QSize* size, const QSize& requestedSize) override;

        private:

            QObject& owner;
    };

}
