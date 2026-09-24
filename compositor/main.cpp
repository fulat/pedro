#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickWindow>
#include <QWaylandCompositor>
#include <systemd/sd-daemon.h>

int main(int argc, char* argv[]) {
    QGuiApplication app(argc, argv);
    QQmlApplicationEngine engine;
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app, [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
    engine.loadFromModule("PedroCompositor", "Main");
    if (engine.rootObjects().isEmpty())
        return 1;
    auto* compositor = qobject_cast<QWaylandCompositor*>(engine.rootObjects().first());
    if (!compositor || !compositor->isCreated())
        return 1;
    // Signal readiness only after the socket exists and the output rendered a frame.
    for (auto* window : QGuiApplication::allWindows()) {
        if (auto* quick = qobject_cast<QQuickWindow*>(window)) {
            QObject::connect(
                quick, &QQuickWindow::frameSwapped, &app,
                [] {
                    static bool ready = false;
                    if (!ready) {
                        sd_notify(0, "READY=1");
                        qInfo("Pedro compositor ready");
                        ready = true;
                    }
                },
                Qt::QueuedConnection);
            quick->show();
        }
    }
    return app.exec();
}
