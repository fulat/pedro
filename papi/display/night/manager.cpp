#include <gio/gio.h>

#include "manager.h"

namespace Pedro::Papi::Display::Night {

    Manager::Manager(QObject* parent) : QObject(parent) {
        auto* source = g_settings_schema_source_get_default();
        auto* schema = source ? g_settings_schema_source_lookup(source, "org.gnome.settings-daemon.plugins.color", true) : nullptr;
        if (!schema) {
            failure = QStringLiteral("GNOME Night Light settings are unavailable");
            return;
        }

        settings = g_settings_new_full(schema, nullptr, nullptr);
        g_settings_schema_unref(schema);
        g_signal_connect(settings, "changed::night-light-enabled", G_CALLBACK(+[](GSettings*, gchar*, gpointer data) { emit static_cast<Manager*>(data)->changed(); }), this);
        g_signal_connect(settings, "writable-changed::night-light-enabled", G_CALLBACK(+[](GSettings*, gchar*, gpointer data) { emit static_cast<Manager*>(data)->changed(); }), this);
    }

    Manager::~Manager() {
        if (settings) {
            g_signal_handlers_disconnect_by_data(settings, this);
            g_object_unref(settings);
        }
    }

    bool Manager::available() const {
        return settings && g_settings_is_writable(settings, "night-light-enabled");
    }

    bool Manager::active() const {
        return settings && g_settings_get_boolean(settings, "night-light-enabled");
    }

    QString Manager::error() const {
        return failure;
    }

    void Manager::toggle() {
        if (!available()) {
            return;
        }

        if (!g_settings_set_boolean(settings, "night-light-enabled", !active())) {
            failure = QStringLiteral("Could not update GNOME Night Light settings");
        } else {
            failure.clear();
        }
        emit changed();
    }
}
