#include "manager.h"
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusServiceWatcher>
#include <QTimer>
#include <algorithm>
namespace Pedro::Papi::Power::Battery {
    namespace {
        constexpr auto service = "org.freedesktop.UPower";
        constexpr auto path = "/org/freedesktop/UPower/devices/DisplayDevice";
        constexpr auto device = "org.freedesktop.UPower.Device";
    }
    Manager::Manager(QObject* parent) : QObject(parent) {
        QDBusConnection::systemBus().connect(service, path, "org.freedesktop.DBus.Properties", "PropertiesChanged", this, SLOT(propertiesChanged(QString, QVariantMap, QStringList)));
        auto* watcher = new QDBusServiceWatcher(service, QDBusConnection::systemBus(), QDBusServiceWatcher::WatchForOwnerChange, this);
        connect(watcher, &QDBusServiceWatcher::serviceOwnerChanged, this, [this] { refresh(); });
        QTimer::singleShot(0, this, &Manager::refresh);
    }
    bool Manager::available() const {
        return present;
    }
    int Manager::value() const {
        return percentage;
    }
    void Manager::propertiesChanged(const QString& interface, const QVariantMap&, const QStringList&) {
        if (interface == device) {
            refresh();
        }
    }
    void Manager::refresh() {
        auto message = QDBusMessage::createMethodCall(service, path, "org.freedesktop.DBus.Properties", "GetAll");
        message << QString::fromLatin1(device);
        auto* watcher = new QDBusPendingCallWatcher(QDBusConnection::systemBus().asyncCall(message), this);
        connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher* call) {
            QDBusPendingReply<QVariantMap> reply = *call;
            call->deleteLater();
            const auto values = reply.isError() ? QVariantMap{} : reply.value();
            present = values.value("IsPresent").toBool();
            percentage = std::clamp(qRound(values.value("Percentage").toDouble()), 0, 100);
            emit changed();
        });
    }
}
