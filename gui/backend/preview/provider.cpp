#include <pedro/papi/gui/preview/manager.h>

#include "provider.h"

namespace Pedro::Gui::Backend::Preview {

    Provider::Provider(Papi::Gui::Preview::Manager& manager) : QQuickImageProvider(QQuickImageProvider::Image), owner(manager) {
    }

    Provider::Provider(QObject& owner) : QQuickImageProvider(QQuickImageProvider::Image), owner(owner) {
    }

    QImage Provider::requestImage(const QString& id, QSize* size, const QSize&) {

        auto* manager = qobject_cast<Papi::Gui::Preview::Manager*>(&owner);

        if (!manager) {
            manager = owner.findChild<Papi::Gui::Preview::Manager*>(id.section('/', 0, 0), Qt::FindDirectChildrenOnly);
        }

        const auto image = manager ? manager->frame() : QImage{};

        if (size) {
            *size = image.size();
        }

        return image;
    }

}
