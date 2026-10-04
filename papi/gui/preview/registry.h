#ifndef PEDRO_PAPI_GUI_PREVIEW_REGISTRY_H
#define PEDRO_PAPI_GUI_PREVIEW_REGISTRY_H

#include <pedro/papi/gui/preview/provider.h>

#include <QMimeType>
#include <QStringList>

#include <functional>
#include <memory>
#include <vector>

namespace Pedro::Papi::Gui::Preview {

    class Registry {
        public:

            using Factory = std::function<std::unique_ptr<Provider>()>;

            Registry();

            void add(QStringList types, Factory factory);

            std::unique_ptr<Provider> create(const QMimeType& mime) const;

        private:

            struct Entry {
                    QStringList types;
                    Factory factory;
            };

            std::vector<Entry> entries;
    };

}

#endif
