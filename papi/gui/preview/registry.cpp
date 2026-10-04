#include <pedro/papi/gui/preview/registry.h>

#include <pedro/papi/gui/preview/document/provider.h>
#include <pedro/papi/gui/preview/image/provider.h>
#include <pedro/papi/gui/preview/media/provider.h>
#include <pedro/papi/gui/preview/text/provider.h>
#include <pedro/papi/gui/preview/unsupported/provider.h>

#include <utility>

namespace Pedro::Papi::Gui::Preview {

    Registry::Registry() {

        add({"image/*"}, [] { return std::make_unique<Image::Provider>(); });
        add({"application/pdf"}, [] { return std::make_unique<Document::Provider>(); });
        add({"video/*"}, [] { return std::make_unique<Media::Provider>(QStringLiteral("video")); });
        add({"audio/*"}, [] { return std::make_unique<Media::Provider>(QStringLiteral("audio")); });
        add({"text/plain", "application/json", "application/xml", "application/javascript", "application/x-shellscript"}, [] { return std::make_unique<Text::Provider>(); });
    }

    void Registry::add(QStringList types, Factory factory) {

        entries.push_back({std::move(types), std::move(factory)});
    }

    std::unique_ptr<Provider> Registry::create(const QMimeType& mime) const {

        for (int pass = 0; pass < 3; ++pass) {
            for (auto entry = entries.rbegin(); entry != entries.rend(); ++entry) {
                for (const auto& type : entry->types) {
                    const bool family = type.endsWith(QStringLiteral("/*"));
                    const bool match = pass == 0 ? mime.name() == type : pass == 1 ? !family && mime.inherits(type) : family && mime.name().startsWith(type.left(type.size() - 1));

                    if (match) {
                        return entry->factory();
                    }
                }
            }
        }

        return std::make_unique<Unsupported::Provider>();
    }

}
