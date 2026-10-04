#include <pedro/papi/gui/preview/unsupported/provider.h>

namespace Pedro::Papi::Gui::Preview::Unsupported {

    Provider::Provider() : Preview::Provider(QStringLiteral("unsupported")) {
    }

    void Provider::open(const QUrl&) {

        current.error = QStringLiteral("No preview is available for this file type.");
        emit changed();
    }

}
