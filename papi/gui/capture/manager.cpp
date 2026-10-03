#include "manager.h"

#include <QDateTime>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusError>
#include <QDBusServiceWatcher>
#include <QDBusPendingCallWatcher>
#include <QDir>
#include <QStandardPaths>
#include <QTimer>

namespace Pedro::Papi::Gui::Capture {
    Manager::Manager(QObject* parent) : QObject(parent) {
        ticker.setInterval(1000);
        connect(&ticker, &QTimer::timeout, this, [this] {
            seconds = static_cast<int>(clock.elapsed() / 1000);
            emit changed();
        });

        auto bus = QDBusConnection::sessionBus();
        bus.connect("org.pedro.Applications", "/org/pedro/Applications", "org.pedro.Applications", "CaptureStopped", this, SLOT(recordingStopped(QString)));
        auto* watcher = new QDBusServiceWatcher("org.pedro.Applications", bus, QDBusServiceWatcher::WatchForUnregistration, this);
        connect(watcher, &QDBusServiceWatcher::serviceUnregistered, this, [this] {
            if (running) {
                recordingStopped(tr("The recording service disconnected."));
            }
        });
    }

    void Manager::recordingStopped(const QString& error) {
        running = false;
        ticker.stop();
        failure = error;
        shown = !failure.isEmpty();
        emit changed();
    }

    bool Manager::busy() const {
        return pending;
    }

    bool Manager::visible() const {
        return shown;
    }

    bool Manager::recording() const {
        return running;
    }

    QString Manager::file() const {
        return destination;
    }

    int Manager::elapsed() const {
        return seconds;
    }

    QString Manager::error() const {
        return failure;
    }

    void Manager::open() {
        if (pending || running) {
            return;
        }
        failure.clear();
        shown = true;
        emit changed();
    }

    void Manager::close() {
        shown = false;
        emit changed();
    }

    void Manager::take(const QRect& area, bool video, bool cursor, int delay) {
        if (pending || running || !shown || area.width() <= 0 || area.height() <= 0) {
            return;
        }

        const auto base = QStandardPaths::writableLocation(QStandardPaths::DesktopLocation);
        const auto directory = base;
        if (base.isEmpty() || !QDir().mkpath(directory)) {
            failure = tr("Could not create the capture folder.");
            emit changed();
            return;
        }

        auto name = QStringLiteral("Pedro-%1").arg(QDateTime::currentDateTime().toString("yyyyMMdd-HHmmss-zzz"));
        if (!video) {
            name += QStringLiteral(".png");
        }
        destination = QDir(directory).filePath(name);
        pending = true;
        shown = false;
        failure.clear();
        emit changed();
        // Let the selection and toolbar disappear before sampling the desktop.
        QTimer::singleShot(qBound(0, delay, 10) * 1000 + 200, this, [this, area, video, cursor] { finish("Capture", {area.x(), area.y(), area.width(), area.height(), video, cursor, destination}); });
    }

    void Manager::stop() {
        if (!running || pending) {
            return;
        }
        pending = true;
        failure.clear();
        emit changed();
        finish("StopCapture", {});
    }

    void Manager::finish(const QString& method, const QList<QVariant>& arguments) {
        auto message = QDBusMessage::createMethodCall("org.pedro.Applications", "/org/pedro/Applications", "org.pedro.Applications", method);
        message.setArguments(arguments);
        auto* watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(message), this);
        connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, method, arguments](QDBusPendingCallWatcher* call) {
            const auto reply = call->reply();
            call->deleteLater();
            pending = false;
            if (reply.type() == QDBusMessage::ErrorMessage || !reply.arguments().value(0).toBool()) {
                failure = reply.type() == QDBusMessage::ErrorMessage ? QDBusError(reply).message() : tr("Screen capture failed.");
                shown = !running;
            } else {
                running = method == "Capture" && arguments.value(4).toBool();
                if (running) {
                    seconds = 0;
                    clock.start();
                    ticker.start();
                } else {
                    ticker.stop();
                }
                if (method == "Capture") {
                    destination = reply.arguments().value(1).toString();
                }
            }
            emit changed();
        });
    }
}
