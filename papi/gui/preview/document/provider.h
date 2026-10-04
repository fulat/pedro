#ifndef PEDRO_PAPI_GUI_PREVIEW_DOCUMENT_PROVIDER_H
#define PEDRO_PAPI_GUI_PREVIEW_DOCUMENT_PROVIDER_H

#include <pedro/papi/gui/preview/provider.h>

#include <memory>

namespace Pedro::Papi::Gui::Preview::Document {

    class Provider final : public Preview::Provider {
        public:

            Provider();

            ~Provider() override;

            void open(const QUrl& source) override;

            void setPage(int page) override;

        private:

            struct Data;

            void render(int page);

            std::shared_ptr<Data> data;
    };

}

#endif
