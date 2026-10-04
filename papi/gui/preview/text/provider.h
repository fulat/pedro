#ifndef PEDRO_PAPI_GUI_PREVIEW_TEXT_PROVIDER_H
#define PEDRO_PAPI_GUI_PREVIEW_TEXT_PROVIDER_H

#include <pedro/papi/gui/preview/provider.h>

namespace Pedro::Papi::Gui::Preview::Text {

    class Provider final : public Preview::Provider {
        public:

            Provider();

            void open(const QUrl& source) override;
    };

}

#endif
