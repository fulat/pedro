#include "manager.h"

#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>

namespace Pedro::Papi::Gui::Capture {
    Manager::Manager(QObject* parent) : QObject(parent) {
    }

    bool Manager::busy() const {
        return pending;
    }

    QString Manager::error() const {
        return failure;
    }

    void Manager::open() {
        if (pending) {
            return;
        }

        pending = true;
        failure.clear();
        emit changed();
        auto message = QDBusMessage::createMethodCall("org.pedro.Applications", "/org/pedro/Applications", "org.pedro.Applications", "SetCaptureVisible");
        message << true;
        auto* watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(message), this);
        connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher* call) {
            QDBusPendingReply<bool> reply = *call;
            call->deleteLater();
            pending = false;
            if (reply.isError()) {
                failure = reply.error().message();
            } else if (!reply.value()) {
                failure = tr("Screen capture is unavailable while another capture is in progress.");
            }
            emit changed();
        });
    }
}
