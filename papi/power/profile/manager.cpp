#include "manager.h"

#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusServiceWatcher>
#include <QDBusVariant>
#include <QTimer>

namespace Pedro::Papi::Power::Profile {
    namespace {
        constexpr auto service = "net.hadess.PowerProfiles";
        constexpr auto path = "/net/hadess/PowerProfiles";
        constexpr auto interface = "net.hadess.PowerProfiles";
    }

    Manager::Manager(QObject* parent) : QObject(parent) {
        QDBusConnection::systemBus().connect(service, path, "org.freedesktop.DBus.Properties", "PropertiesChanged", this, SLOT(propertiesChanged(QString, QVariantMap, QStringList)));

        auto* watcher = new QDBusServiceWatcher(service, QDBusConnection::systemBus(), QDBusServiceWatcher::WatchForOwnerChange, this);
        connect(watcher, &QDBusServiceWatcher::serviceOwnerChanged, this, [this] { refresh(); });

        QTimer::singleShot(0, this, &Manager::refresh);
    }

    bool Manager::available() const {
        return supported;
    }

    bool Manager::active() const {
        return supported && current == "power-saver";
    }

    bool Manager::busy() const {
        return pending;
    }

    QString Manager::error() const {
        return failure;
    }

    void Manager::propertiesChanged(const QString& changedInterface, const QVariantMap&, const QStringList&) {
        if (changedInterface == interface) {
            refresh();
        }
    }

    void Manager::refresh() {
        auto message = QDBusMessage::createMethodCall(service, path, "org.freedesktop.DBus.Properties", "GetAll");
        message << QString::fromLatin1(interface);

        auto* watcher = new QDBusPendingCallWatcher(QDBusConnection::systemBus().asyncCall(message), this);
        connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher* call) {
            QDBusPendingReply<QVariantMap> reply = *call;
            call->deleteLater();
            supported = false;

            if (reply.isError()) {
                failure = reply.error().message();
            } else {
                const auto values = reply.value();
                current = values.value("ActiveProfile").toString();
                const auto profiles = qdbus_cast<QList<QVariantMap>>(values.value("Profiles"));
                for (const auto& profile : profiles) {
                    if (profile.value("Profile").toString() == "power-saver") {
                        supported = true;
                    }
                }
                failure.clear();
            }

            emit changed();
        });
    }

    void Manager::toggle() {
        if (!supported || pending) {
            return;
        }

        if (!active()) {
            previous = current;
        }
        const auto target = active() ? previous : QStringLiteral("power-saver");
        auto message = QDBusMessage::createMethodCall(service, path, "org.freedesktop.DBus.Properties", "Set");
        message << QString::fromLatin1(interface) << QStringLiteral("ActiveProfile") << QVariant::fromValue(QDBusVariant(target));
        pending = true;
        failure.clear();
        emit changed();

        auto* watcher = new QDBusPendingCallWatcher(QDBusConnection::systemBus().asyncCall(message), this);
        connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher* call) {
            QDBusPendingReply<> reply = *call;
            call->deleteLater();
            pending = false;
            if (reply.isError()) {
                failure = reply.error().message();
                emit changed();
            } else {
                refresh();
            }
        });
    }
}
