#include "manager.h"
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
    void Manager::propertiesChanged(const QString& interface, const QVariantMap& values, const QStringList& invalidated) {
        if ((interface == manager && (values.contains("PrimaryConnection") || invalidated.contains("PrimaryConnection"))) || interface == active) {
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
            const auto address = reply.isError() ? QString() : reply.value().variant().value<QDBusObjectPath>().path();
            if (address.isEmpty() || address == "/") {
                kind = "none";
                label.clear();
                emit changed();
                return;
            }
            auto message = QDBusMessage::createMethodCall(service, address, properties, "GetAll");
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
                emit changed();
            });
        });
    }
}
