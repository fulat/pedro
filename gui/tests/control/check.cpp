#include <gio/gio.h>

#include "papi/gui/focus/manager.h"
#include "papi/power/profile/manager.h"

#include <QCoreApplication>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusReply>
#include <QDBusVariant>
#include <QElapsedTimer>
#include <QThread>

#include <iostream>

namespace {

    constexpr auto service = "net.hadess.PowerProfiles";
    constexpr auto path = "/net/hadess/PowerProfiles";

    QString profile() {
        auto message = QDBusMessage::createMethodCall(service, path, "org.freedesktop.DBus.Properties", "Get");
        message << QString::fromLatin1(service) << QStringLiteral("ActiveProfile");
        QDBusReply<QDBusVariant> reply = QDBusConnection::systemBus().call(message);
        return reply.isValid() ? reply.value().variant().toString() : QString{};
    }

    bool setProfile(const QString& value) {
        auto message = QDBusMessage::createMethodCall(service, path, "org.freedesktop.DBus.Properties", "Set");
        message << QString::fromLatin1(service) << QStringLiteral("ActiveProfile") << QVariant::fromValue(QDBusVariant(value));
        return QDBusConnection::systemBus().call(message).type() != QDBusMessage::ErrorMessage;
    }

    struct Restore {
            GSettings* settings = g_settings_new("org.gnome.desktop.notifications");
            bool banners = g_settings_get_boolean(settings, "show-banners");
            QString original = profile();

            ~Restore() {
                g_settings_set_boolean(settings, "show-banners", banners);
                g_settings_sync();
                g_object_unref(settings);
                if (!original.isEmpty()) {
                    setProfile(original);
                }
            }
    };
}

int main(int argc, char** argv) {
    QCoreApplication app(argc, argv);
    Restore restore;
    Pedro::Papi::Power::Profile::Manager power;
    Pedro::Papi::Gui::Focus::Manager focus;
    auto wait = [&](auto condition) {
        QElapsedTimer timer;
        timer.start();
        while (!condition() && timer.elapsed() < 5000) {
            app.processEvents();
            QThread::msleep(10);
        }
        return condition();
    };
    auto require = [](bool success, const char* message) {
        if (!success) {
            std::cerr << "FAIL: " << message << '\n';
        }
        return success;
    };

    if (!require(wait([&] { return power.available(); }) && focus.available(), "system controls available")) {
        return 1;
    }
    const bool initialFocus = focus.active();
    focus.toggle();
    if (!require(wait([&] { return focus.active() != initialFocus; }) && bool(g_settings_get_boolean(restore.settings, "show-banners")) == initialFocus, "Focus controls GNOME banners")) {
        return 1;
    }
    g_settings_set_boolean(restore.settings, "show-banners", restore.banners);
    if (!require(wait([&] { return focus.active() == initialFocus; }), "external Focus updates")) {
        return 1;
    }

    const bool initialPower = power.active();
    power.toggle();
    if (!require(wait([&] { return !power.busy() && power.active() != initialPower; }) && (profile() == "power-saver") != initialPower, "Power Saving controls real profile")) {
        std::cerr << power.error().toStdString() << '\n';
        return 1;
    }
    power.toggle();
    if (!require(wait([&] { return !power.busy() && power.active() == initialPower; }) && profile() == restore.original, "restore previous profile")) {
        return 1;
    }
    setProfile(initialPower ? "balanced" : "power-saver");
    if (!require(wait([&] { return power.active() != initialPower; }), "external power updates")) {
        return 1;
    }

    std::cout << "PASS: GNOME Focus and Power Saving, external updates and profile restoration\n";
    return 0;
}
