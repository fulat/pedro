#include "papi/gui/capture/manager.h"

#include <QCoreApplication>
#include <QDBusConnection>
#include <QElapsedTimer>
#include <QThread>

#include <iostream>

class Bridge final : public QObject {
        Q_OBJECT
        Q_CLASSINFO("D-Bus Interface", "org.pedro.Applications")

    public:

        int calls = 0;
        bool allowed = true;

    public slots:
        bool SetCaptureVisible(bool visible) {
            ++calls;
            return visible && allowed;
        }
};

int main(int argc, char** argv) {
    QCoreApplication application(argc, argv);
    auto bus = QDBusConnection::sessionBus();
    Bridge bridge;
    if (!bus.registerService("org.pedro.Applications") || !bus.registerObject("/org/pedro/Applications", &bridge, QDBusConnection::ExportAllSlots)) {
        return 1;
    }
    Pedro::Papi::Gui::Capture::Manager manager;
    auto wait = [&] {
        QElapsedTimer timer;
        timer.start();
        while (manager.busy() && timer.elapsed() < 3000) {
            application.processEvents();
            QThread::msleep(5);
        }
        return !manager.busy();
    };
    manager.open();
    manager.open();
    if (!wait() || bridge.calls != 1 || !manager.error().isEmpty()) {
        return 1;
    }
    bridge.allowed = false;
    manager.open();
    if (!wait() || manager.error().isEmpty()) {
        return 1;
    }
    bus.unregisterService("org.pedro.Applications");
    manager.open();
    if (!wait() || manager.error().isEmpty()) {
        return 1;
    }
    std::cout << "PASS: capture launch, duplicate requests and bridge errors\n";
}

#include "check.moc"
