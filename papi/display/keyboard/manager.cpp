#include <gio/gio.h>

#include "manager.h"

#include <QFile>
#include <QVariantMap>
#include <QXmlStreamReader>

namespace Pedro::Papi::Display::Keyboard {
    namespace {
        QHash<QString, QString> layoutNames() {
            QHash<QString, QString> names;
            QFile file(QStringLiteral("/usr/share/X11/xkb/rules/evdev.xml"));
            if (!file.open(QIODevice::ReadOnly)) {
                return names;
            }

            QXmlStreamReader xml(&file);
            bool inLayout = false;
            bool inVariant = false;
            QString layout;
            QString name;
            QString description;
            while (!xml.atEnd()) {
                xml.readNext();
                if (xml.isStartElement()) {
                    if (xml.name() == "layout") {
                        inLayout = true;
                    } else if (xml.name() == "variant" && inLayout) {
                        inVariant = true;
                    } else if (xml.name() == "configItem" && inLayout) {
                        name.clear();
                        description.clear();
                    } else if (xml.name() == "name" && inLayout) {
                        name = xml.readElementText();
                    } else if (xml.name() == "description" && inLayout) {
                        description = xml.readElementText();
                    }
                } else if (xml.isEndElement()) {
                    if (xml.name() == "configItem" && inLayout) {
                        if (!inVariant) {
                            layout = name;
                        }
                        names.insert(inVariant ? layout + "+" + name : layout, description);
                    } else if (xml.name() == "variant") {
                        inVariant = false;
                    } else if (xml.name() == "layout") {
                        inLayout = false;
                    }
                }
            }
            return names;
        }
    }

    Manager::Manager(QObject* parent) : QObject(parent), names(layoutNames()) {
        auto* source = g_settings_schema_source_get_default();
        auto* schema = source ? g_settings_schema_source_lookup(source, "org.gnome.desktop.input-sources", true) : nullptr;
        if (!schema) {
            return;
        }

        settings = g_settings_new_full(schema, nullptr, nullptr);
        g_settings_schema_unref(schema);
        g_signal_connect(settings, "changed::sources", G_CALLBACK(+[](GSettings*, gchar*, gpointer data) { emit static_cast<Manager*>(data)->changed(); }), this);
    }

    Manager::~Manager() {
        if (settings) {
            g_signal_handlers_disconnect_by_data(settings, this);
            g_object_unref(settings);
        }
    }

    QVariantList Manager::layouts() const {
        QVariantList result;
        if (!settings) {
            return result;
        }

        auto* sources = g_settings_get_value(settings, "sources");
        GVariantIter iterator;
        g_variant_iter_init(&iterator, sources);
        const gchar* type = nullptr;
        const gchar* id = nullptr;
        while (g_variant_iter_next(&iterator, "(&s&s)", &type, &id)) {
            const auto identifier = QString::fromUtf8(id);
            const auto sourceType = QString::fromUtf8(type);
            const auto description = sourceType == "xkb" ? names.value(identifier, identifier) : identifier;
            result.append(QVariantMap{{"id", identifier}, {"type", sourceType}, {"name", description.isEmpty() ? identifier : description}});
        }
        g_variant_unref(sources);
        return result;
    }
}
