#include <gio/gio.h>

#include "manager.h"

namespace Pedro::Papi::Gui::Focus {

    Manager::Manager(QObject* parent) : QObject(parent) {
        auto* source = g_settings_schema_source_get_default();
        auto* schema = source ? g_settings_schema_source_lookup(source, "org.gnome.desktop.notifications", true) : nullptr;
        if (!schema) {
            failure = QStringLiteral("GNOME notification settings are unavailable");
            return;
        }

        settings = g_settings_new_full(schema, nullptr, nullptr);
        g_settings_schema_unref(schema);
        g_signal_connect(settings, "changed::show-banners", G_CALLBACK(+[](GSettings*, gchar*, gpointer data) { emit static_cast<Manager*>(data)->changed(); }), this);
        g_signal_connect(settings, "writable-changed::show-banners", G_CALLBACK(+[](GSettings*, gchar*, gpointer data) { emit static_cast<Manager*>(data)->changed(); }), this);
    }

    Manager::~Manager() {
        if (settings) {
            g_signal_handlers_disconnect_by_data(settings, this);
            g_object_unref(settings);
        }
    }

    bool Manager::available() const {
        return settings && g_settings_is_writable(settings, "show-banners");
    }

    bool Manager::active() const {
        return settings && !g_settings_get_boolean(settings, "show-banners");
    }

    QString Manager::error() const {
        return failure;
    }

    void Manager::toggle() {
        if (!available()) {
            return;
        }

        if (!g_settings_set_boolean(settings, "show-banners", active())) {
            failure = QStringLiteral("Could not update GNOME notification settings");
        } else {
            failure.clear();
        }
        emit changed();
    }
}
