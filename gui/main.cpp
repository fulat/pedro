#include <QDir>
#include "icons.hpp"
#include "render/info.hpp"
#include <QFont>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickWindow>
#include <QTimer>

int main(int argc, char* argv[]) {

    QGuiApplication::setHighDpiScaleFactorRoundingPolicy(Qt::HighDpiScaleFactorRoundingPolicy::PassThrough);
    const auto textRenderer = qEnvironmentVariable("PEDRO_TEXT_RENDERING");
    QQuickWindow::setTextRenderType(textRenderer == "qt" ? QQuickWindow::QtTextRendering : QQuickWindow::NativeTextRendering);

    QGuiApplication app(argc, argv);
    QCoreApplication::setApplicationName(QStringLiteral("Pedro"));
    QCoreApplication::setOrganizationName(QStringLiteral("Pedro"));
    QFont interfaceFont(QStringLiteral("Noto Sans"));

    interfaceFont.setPixelSize(12);
    interfaceFont.setHintingPreference(QFont::PreferFullHinting);
    interfaceFont.setStyleStrategy(static_cast<QFont::StyleStrategy>(QFont::PreferAntialias | QFont::PreferQuality));
    app.setFont(interfaceFont);

    QQmlApplicationEngine engine;
    engine.addImageProvider("icons", new Icons);
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app, []() { QCoreApplication::exit(-1); }, Qt::QueuedConnection);
    const auto qmlDirectory = qEnvironmentVariable("PEDRO_QML_DIR");
    if (qmlDirectory.isEmpty()) {
        engine.loadFromModule("gui", "Main");
    } else {
        engine.load(QUrl::fromLocalFile(QDir(qmlDirectory).filePath(QStringLiteral("Main.qml"))));
    }

    auto* window = engine.rootObjects().isEmpty() ? nullptr : qobject_cast<QQuickWindow*>(engine.rootObjects().first());
    if (window && qEnvironmentVariableIsSet("PEDRO_RENDER_DIAGNOSTICS"))
        Pedro::Gui::Render::Info::attach(*window);

    // Development capture uses the actual shell and its live QML components.
    const auto capturePath = qEnvironmentVariable("PEDRO_CAPTURE");
    if (!capturePath.isEmpty() && qEnvironmentVariableIsSet("PEDRO_DEVELOPMENT_MODE") && window) {
        const auto captureMode = qEnvironmentVariable("PEDRO_CAPTURE_MODE");
        window->setProperty("panelMode", captureMode.isEmpty() ? QStringLiteral("quick") : captureMode);

        bool hasCaptureAnchor = false;
        const auto captureAnchor = qEnvironmentVariable("PEDRO_CAPTURE_ANCHOR").toDouble(&hasCaptureAnchor);

        if (hasCaptureAnchor) {
            window->setProperty("panelAnchorX", captureAnchor);
        }

        QTimer::singleShot(1000, &app, [window, capturePath] { QCoreApplication::exit(window->grabWindow().save(capturePath) ? 0 : 1); });
    }
    return QGuiApplication::exec();
}
