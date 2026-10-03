#include <gio/gio.h>

#include "papi/display/keyboard/manager.h"

#include <QCoreApplication>
#include <QVariantMap>

#include <iostream>

int main(int argc, char** argv) {
    // The memory backend isolates fixtures from the user's keyboard configuration.
    qputenv("GSETTINGS_BACKEND", "memory");
    QCoreApplication application(argc, argv);
    auto* settings = g_settings_new("org.gnome.desktop.input-sources");
    GVariantBuilder builder;
    g_variant_builder_init(&builder, G_VARIANT_TYPE("a(ss)"));
    g_variant_builder_add(&builder, "(ss)", "xkb", "us");
    g_variant_builder_add(&builder, "(ss)", "xkb", "es");
    g_variant_builder_add(&builder, "(ss)", "xkb", "us+dvorak");
    g_variant_builder_add(&builder, "(ss)", "ibus", "test-engine");
    g_settings_set_value(settings, "sources", g_variant_builder_end(&builder));

    Pedro::Papi::Display::Keyboard::Manager manager;
    const auto layouts = manager.layouts();
    if (layouts.size() != 4 || layouts[0].toMap().value("id") != "us" || layouts[1].toMap().value("id") != "es" || layouts[2].toMap().value("name").toString() == "us+dvorak" || layouts[3].toMap().value("name") != "test-engine") {
        std::cerr << "FAIL: source ordering, XKB variant names or IBus fallback\n";
        return 1;
    }

    int changes = 0;
    QObject::connect(&manager, &Pedro::Papi::Display::Keyboard::Manager::changed, [&] { ++changes; });
    g_settings_set_value(settings, "sources", g_variant_new_array(G_VARIANT_TYPE("(ss)"), nullptr, 0));
    application.processEvents();
    g_object_unref(settings);
    if (changes == 0 || !manager.layouts().isEmpty()) {
        std::cerr << "FAIL: input sources update notification\n";
        return 1;
    }
    std::cout << "PASS: configured sources, XKB labels, IBus fallback, live updates and empty list\n";
}
