#include "manager.h"

#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusServiceWatcher>
#include <QDebug>

namespace Pedro::Papi::Gui::Appearance::Glass {
    namespace {
        constexpr auto service = "org.pedro.Applications";
        constexpr auto path = "/org/pedro/Applications";
    }

    Manager::Manager(QObject* parent) : QObject(parent) {
        auto* watcher = new QDBusServiceWatcher(service, QDBusConnection::sessionBus(), QDBusServiceWatcher::WatchForOwnerChange, this);
        connect(watcher, &QDBusServiceWatcher::serviceOwnerChanged, this, [this](const QString&, const QString&, const QString& owner) {
            if (!owner.isEmpty()) {
                for (const auto& title : titles) {
                    sendTitle(title);
                }
            }
        });
    }

    void Manager::registerTitle(const QString& title) {
        if (title.isEmpty() || titles.contains(title)) {
            return;
        }

        titles.append(title);
        sendTitle(title);
    }

    void Manager::sendTitle(const QString& title) {
        auto message = QDBusMessage::createMethodCall(service, path, service, "SetGlass");
        message << title;

        auto* watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(message), this);
        connect(watcher, &QDBusPendingCallWatcher::finished, this, [](QDBusPendingCallWatcher* call) {
            QDBusPendingReply<> reply = *call;
            if (reply.isError()) {
                qWarning() << "Pedro compositor glass unavailable:" << reply.error().message();
            }
            call->deleteLater();
        });
    }
}
