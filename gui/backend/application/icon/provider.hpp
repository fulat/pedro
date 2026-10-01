#pragma once

#include <QQuickImageProvider>

namespace Pedro::Gui::Backend::Application::Icon {

    // Resolves full-color application icons from files or the active icon theme.
    class Provider final : public QQuickImageProvider {

        public:

            Provider();

            QImage requestImage(const QString& id, QSize* size, const QSize& requestedSize) override;
    };

} // namespace Pedro::Gui::Backend::Application::Icon
