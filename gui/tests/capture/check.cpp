#include "papi/gui/capture/manager.h"

#include <QCoreApplication>
#include <QDBusConnection>
#include <QElapsedTimer>
#include <QStandardPaths>
#include <QThread>

#include <iostream>

class Bridge final : public QObject {
        Q_OBJECT
        Q_CLASSINFO("D-Bus Interface", "org.pedro.Applications")

    public:

        int calls = 0;
        bool allowed = true;

    public slots:
        bool Capture(int, int, int width, int height, bool video, bool, const QString& filename, QString& saved) {
            ++calls;
            saved = filename + (video ? ".webm" : "");
            return allowed && width > 0 && height > 0;
        }

        bool StopCapture() {
            return allowed;
        }
};

int main(int argc, char** argv) {
    qputenv("XDG_CONFIG_HOME", argv[1]);
    QCoreApplication application(argc, argv);
    if (!QStandardPaths::writableLocation(QStandardPaths::PicturesLocation).startsWith(QString::fromLocal8Bit(argv[1]))) {
        return 1;
    }
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
    if (!manager.visible() || bridge.calls != 0) {
        return 1;
    }
    const QRect region(10, 20, 300, 200);
    manager.take(region, false, false, 0);
    manager.take(region, false, false, 0);
    if (!wait() || bridge.calls != 1 || !manager.error().isEmpty() || manager.visible() || !manager.file().endsWith(".png")) {
        return 1;
    }
    manager.open();
    manager.take(region, true, true, 0);
    if (!wait() || !manager.recording() || !manager.file().endsWith(".webm")) {
        return 1;
    }
    manager.stop();
    if (!wait() || manager.recording()) {
        return 1;
    }
    bridge.allowed = false;
    manager.open();
    manager.take(region, false, false, 0);
    if (!wait() || manager.error().isEmpty() || !manager.visible()) {
        return 1;
    }
    bus.unregisterService("org.pedro.Applications");
    manager.take(region, false, false, 0);
    if (!wait() || manager.error().isEmpty()) {
        return 1;
    }
    std::cout << "PASS: Pedro toolbar state, image/video capture, stop, duplicate requests and errors\n";
}

#include "check.moc"
