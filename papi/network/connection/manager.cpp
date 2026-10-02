#include "manager.h"

#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusServiceWatcher>
#include <QDBusVariant>
#include <QTimer>

namespace Pedro::Papi::Network::Connection {
    namespace {
        constexpr auto service = "org.freedesktop.NetworkManager";
        constexpr auto path = "/org/freedesktop/NetworkManager";
        constexpr auto manager = "org.freedesktop.NetworkManager";
        constexpr auto active = "org.freedesktop.NetworkManager.Connection.Active";
        constexpr auto ipv4 = "org.freedesktop.NetworkManager.IP4Config";
        constexpr auto ipv6 = "org.freedesktop.NetworkManager.IP6Config";
        constexpr auto properties = "org.freedesktop.DBus.Properties";
    }

    Manager::Manager(QObject* parent) : QObject(parent) {
        QDBusConnection::systemBus().connect(service, QString(), properties, "PropertiesChanged", this, SLOT(propertiesChanged(QString, QVariantMap, QStringList)));
        auto* watcher = new QDBusServiceWatcher(service, QDBusConnection::systemBus(), QDBusServiceWatcher::WatchForOwnerChange, this);
        connect(watcher, &QDBusServiceWatcher::serviceOwnerChanged, this, [this] { refresh(); });
        QTimer::singleShot(0, this, &Manager::refresh);
    }

    QString Manager::type() const {
        return kind;
    }

    QString Manager::name() const {
        return label;
    }

    QString Manager::ipAddress() const {
        return address;
    }

    void Manager::propertiesChanged(const QString& interface, const QVariantMap& values, const QStringList& invalidated) {
        if ((interface == manager && (values.contains("PrimaryConnection") || invalidated.contains("PrimaryConnection"))) || interface == active || interface == ipv4 || interface == ipv6) {
            refresh();
        }
    }

    void Manager::refresh() {
        const auto version = ++revision;
        auto message = QDBusMessage::createMethodCall(service, path, properties, "Get");
        message << QString::fromLatin1(manager) << QStringLiteral("PrimaryConnection");
        auto* watcher = new QDBusPendingCallWatcher(QDBusConnection::systemBus().asyncCall(message), this);
        connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, version](QDBusPendingCallWatcher* call) {
            QDBusPendingReply<QDBusVariant> reply = *call;
            call->deleteLater();
            if (version != revision) {
                return;
            }
            const auto connectionPath = reply.isError() ? QString() : reply.value().variant().value<QDBusObjectPath>().path();
            if (connectionPath.isEmpty() || connectionPath == "/") {
                kind = "none";
                label.clear();
                address.clear();
                emit changed();
                return;
            }
            auto message = QDBusMessage::createMethodCall(service, connectionPath, properties, "GetAll");
            message << QString::fromLatin1(active);
            auto* next = new QDBusPendingCallWatcher(QDBusConnection::systemBus().asyncCall(message), this);
            connect(next, &QDBusPendingCallWatcher::finished, this, [this, version](QDBusPendingCallWatcher* call) {
                QDBusPendingReply<QVariantMap> reply = *call;
                call->deleteLater();
                if (version != revision) {
                    return;
                }
                const auto values = reply.isError() ? QVariantMap{} : reply.value();
                const auto type = values.value("Type").toString();
                kind = type == "802-11-wireless" ? "wifi" : type == "802-3-ethernet" ? "ethernet" : type.isEmpty() ? "none" : "other";
                label = values.value("Id").toString();
                this->address.clear();
                emit changed();

                refreshAddress(values.value("Ip4Config").value<QDBusObjectPath>().path(), values.value("Ip6Config").value<QDBusObjectPath>().path(), version);
            });
        });
    }

    void Manager::refreshAddress(const QString& configuration, const QString& fallback, int version, bool useIpv6) {

        if (version != revision) {
            return;
        }

        if (configuration.isEmpty() || configuration == "/") {
            if (!useIpv6) {
                refreshAddress(fallback, {}, version, true);
            }
            return;
        }

        auto message = QDBusMessage::createMethodCall(service, configuration, properties, "GetAll");
        message << QString::fromLatin1(useIpv6 ? ipv6 : ipv4);

        auto* watcher = new QDBusPendingCallWatcher(QDBusConnection::systemBus().asyncCall(message), this);
        connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, fallback, version, useIpv6](QDBusPendingCallWatcher* call) {
            QDBusPendingReply<QVariantMap> reply = *call;
            call->deleteLater();

            if (version != revision) {
                return;
            }

            const auto values = reply.isError() ? QVariantMap{} : reply.value();
            const auto addresses = qdbus_cast<QList<QVariantMap>>(values.value("AddressData"));

            for (const auto& entry : addresses) {
                const auto value = entry.value("address").toString();
                if (!value.isEmpty()) {
                    address = value;
                    emit changed();
                    return;
                }
            }

            if (!useIpv6) {
                refreshAddress(fallback, {}, version, true);
            }
        });
    }
}
