#include "manager.h"

#include <QDBusConnection>
#include <QDBusServiceWatcher>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusVariant>

#include <algorithm>

namespace Pedro::Papi::Display::Brightness {

    namespace {
        constexpr auto service = "org.gnome.SettingsDaemon.Power";
        constexpr auto path = "/org/gnome/SettingsDaemon/Power";
        constexpr auto screen = "org.gnome.SettingsDaemon.Power.Screen";
        constexpr auto properties = "org.freedesktop.DBus.Properties";
    }

    Manager::Manager(QObject* parent) : QObject(parent), serviceWatcher(new QDBusServiceWatcher(service, QDBusConnection::sessionBus(), QDBusServiceWatcher::WatchForOwnerChange, this)) {
        QDBusConnection::sessionBus().connect(service, path, properties, "PropertiesChanged", this, SLOT(propertiesChanged(QString, QVariantMap, QStringList)));
        connect(serviceWatcher, &QDBusServiceWatcher::serviceOwnerChanged, this, [this] {
            ++revision;
            supported = false;
            requested = -1;
            debounce.stop();
            emit changed();
            refresh();
        });
        debounce.setSingleShot(true);
        debounce.setInterval(75);
        connect(&debounce, &QTimer::timeout, this, &Manager::write);
        QTimer::singleShot(0, this, &Manager::refresh);
    }

    bool Manager::available() const {
        return supported;
    }

    int Manager::value() const {
        return percentage;
    }

    QString Manager::error() const {
        return failure;
    }

    void Manager::apply(int value) {
        supported = value >= 0 && value <= 100;
        percentage = supported ? value : 0;
        if (!supported) {
            requested = -1;
            debounce.stop();
        }
        failure.clear();
        emit changed();
    }

    void Manager::refresh() {
        auto message = QDBusMessage::createMethodCall(service, path, properties, "GetAll");
        message << QString::fromLatin1(screen);
        const auto version = ++revision;
        auto* watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(message), this);
        connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, version](QDBusPendingCallWatcher* call) {
            const QDBusPendingReply<QVariantMap> reply = *call;
            call->deleteLater();
            if (version != revision) {
                return;
            }
            if (reply.isError()) {
                apply(-1);
                failure = reply.error().message();
                emit changed();
                return;
            }
            const auto values = reply.value();
            bool valid = false;
            const auto value = values.value("Brightness").toInt(&valid);
            apply(valid ? value : -1);
        });
    }

    void Manager::propertiesChanged(const QString& interface, const QVariantMap& values, const QStringList& invalidated) {
        if (interface != screen) {
            return;
        }
        if (values.contains("Brightness")) {
            ++revision;
            bool valid = false;
            const auto value = values.value("Brightness").toInt(&valid);
            apply(valid ? value : -1);
        } else if (invalidated.contains("Brightness")) {
            refresh();
        }
    }

    void Manager::setValue(int value) {
        if (!supported) {
            return;
        }
        requested = std::clamp(value, 0, 100);
        debounce.start();
    }

    void Manager::write() {
        if (!supported || writing || requested < 0) {
            return;
        }
        const auto value = requested;
        requested = -1;
        writing = true;
        auto message = QDBusMessage::createMethodCall(service, path, properties, "Set");
        message << QString::fromLatin1(screen) << QStringLiteral("Brightness") << QVariant::fromValue(QDBusVariant(value));
        auto* watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(message), this);
        connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher* call) {
            const QDBusPendingReply<> reply = *call;
            call->deleteLater();
            writing = false;
            if (reply.isError()) {
                failure = reply.error().message();
                emit changed();
            } else {
                refresh();
            }
            if (requested >= 0) {
                debounce.start();
            }
        });
    }
}
