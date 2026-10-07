#include <pedro/papi/io/directory/model.hpp>
#include <pedro/papi/io/tag/model.h>
#include <pedro/papi/io/content/applications.hpp>

#include "backend.hpp"
#include "application/icon/provider.hpp"
#include "icons.hpp"
#include "render/info.hpp"
#include "preview/provider.h"
#include "thumbnail/provider.h"

#include <QCommandLineParser>
#include <QDebug>
#include <QDir>
#include <QFileInfo>
#include <QGuiApplication>
#include <QIcon>
#include <QLibraryInfo>
#include <QMetaObject>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <pedro/papi/io/file/information.h>
#include <QQuickWindow>
#include <QTimer>
#include <QTranslator>
#include <QLocale>
#include <memory>

#include <pedro/papi/gui/appearance/config/config.hpp>

int main(int argc, char* argv[]) {

#if defined(Q_OS_LINUX)
    const auto plugins = QLibraryInfo::path(QLibraryInfo::PluginsPath);

    const auto hasGnomeTheme = QFileInfo::exists(QDir(plugins).filePath(QStringLiteral("platformthemes/libqgnomeplatformtheme.so")));

    const auto hasGnomeDecoration = QFileInfo::exists(QDir(plugins).filePath(QStringLiteral("wayland-decoration-client/"
                                                                                            "libqgnomeplatformdecoration.so")));

    if (qEnvironmentVariableIsEmpty("QT_QPA_PLATFORMTHEME")) {
        qputenv("QT_QPA_PLATFORMTHEME", hasGnomeTheme ? "gnome" : "gtk3");
    }

    if (qEnvironmentVariableIsEmpty("QT_WAYLAND_DECORATION")) {
        qputenv("QT_WAYLAND_DECORATION", hasGnomeDecoration ? "qgnomeplatform" : "adwaita");
    }
#endif

    QGuiApplication::setHighDpiScaleFactorRoundingPolicy(Qt::HighDpiScaleFactorRoundingPolicy::PassThrough);

    const auto textRenderer = qEnvironmentVariable("PEDRO_TEXT_RENDERING");

    QQuickWindow::setTextRenderType(textRenderer == "qt" ? QQuickWindow::QtTextRendering : QQuickWindow::NativeTextRendering);

    QGuiApplication app(argc, argv);

    QCoreApplication::setApplicationName(QStringLiteral("Pedro"));

    QCoreApplication::setOrganizationName(QStringLiteral("Pedro"));

    QCommandLineParser arguments;
    arguments.addHelpOption();
    arguments.addOption({QStringLiteral("preview"), QStringLiteral("Open a file in the internal preview window."), QStringLiteral("file")});
    arguments.process(app);

    Icons::configureTheme();

    /*
     * Backend exposed to QML.
     *
     * This must be registered before Main.qml is loaded,
     * otherwise QML will not know what "Backend" is.
     */
    Backend backend(nullptr);
    Backend::setInstance(&backend);

    // The engine is created after its backend so QML releases first at shutdown.
    QQmlApplicationEngine engine;

    std::unique_ptr<QTranslator> translator;
    const auto translate = [&] {
        auto next = std::make_unique<QTranslator>();
        if (!next->load(":/pedro/language/" + backend.language() + ".qm")) {
            qWarning() << "Could not load Pedro language:" << backend.language();
            return;
        }
        if (translator) {
            app.removeTranslator(translator.get());
        }
        translator = std::move(next);
        app.installTranslator(translator.get());
        QLocale::setDefault(QLocale(backend.language()));
        engine.retranslate();
        qInfo() << "Pedro language:" << backend.language();
    };
    QObject::connect(&backend, &Backend::languageChanged, &engine, translate);
    translate();

    qmlRegisterType<Pedro::Papi::Io::Content::Applications>("Pedro.Files", 1, 0, "Applications");
    qmlRegisterType<Pedro::Papi::Io::File::Information>("Pedro.Files", 1, 0, "Information");
    qmlRegisterSingletonType<Pedro::Papi::Io::Tag::Model>("Pedro.Files", 1, 0, "Tags", [](QQmlEngine* engine, QJSEngine*) -> QObject* {
        return new Pedro::Papi::Io::Tag::Model(engine);
    });
    qmlRegisterType<Pedro::Papi::Io::Directory::Model>("Pedro.Files", 1, 0, "Directory");
    engine.rootContext()->setContextProperty(QStringLiteral("Backend"), &backend);

    /*
     * Pedro icon provider.
     */
    engine.addImageProvider("icons", new Icons);
    engine.addImageProvider("thumbnails", new Pedro::Gui::Backend::Thumbnail::Provider);
    engine.addImageProvider("preview", new Pedro::Gui::Backend::Preview::Provider(backend));

    // Full-color desktop application icons supplied by GLib application data.
    engine.addImageProvider("applications", new Pedro::Gui::Backend::Application::Icon::Provider);

    /*
     * Quit cleanly if the root QML object cannot
     * be created.
     */
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app, []() { QCoreApplication::exit(-1); }, Qt::QueuedConnection);

    /*
     * Development mode loads the QML directly
     * from the source tree.
     *
     * Production loads the compiled QML module.
     */
    const auto qmlDirectory = qEnvironmentVariable("PEDRO_QML_DIR");

    if (qmlDirectory.isEmpty()) {
        engine.loadFromModule("gui", "Main");
    } else {
        engine.load(QUrl::fromLocalFile(QDir(qmlDirectory).filePath(QStringLiteral("Main.qml"))));
    }

    /*
     * Retrieve Pedro's root window.
     */
    auto* window = engine.rootObjects().isEmpty() ? nullptr : qobject_cast<QQuickWindow*>(engine.rootObjects().first());

    if (!window) {
        qCritical() << "Pedro failed to create its main window";

        return 1;
    }

    // Controller object used by native development and capture tooling.
    auto* applicationController = window->findChild<QObject*>(QStringLiteral("applicationController"));

    if (!applicationController) {
        qCritical() << "Pedro failed to create its application controller";

        return 1;
    }

    if (arguments.isSet(QStringLiteral("preview"))) {
        const auto source = QUrl::fromUserInput(arguments.value(QStringLiteral("preview")), QDir::currentPath(), QUrl::AssumeLocalFile);

        QTimer::singleShot(0, &backend, [&backend, source] { backend.openPreview(source); });
    }

    const auto developmentMode = qEnvironmentVariableIsSet("PEDRO_DEVELOPMENT_MODE");

    /*
     * In development we explicitly show and
     * activate the shell window.
     */
    if (developmentMode) {
        window->show();

        QTimer::singleShot(0, window, [window] { window->requestActivate(); });
    }

    /*
     * Optional rendering diagnostics.
     */
    if (qEnvironmentVariableIsSet("PEDRO_RENDER_DIAGNOSTICS")) {
        Pedro::Gui::Render::Info::attach(*window);
    }

    /*
     * Development capture uses the real shell
     * and its live QML components.
     */
    const auto capturePath = qEnvironmentVariable("PEDRO_CAPTURE");

    if (!capturePath.isEmpty() && developmentMode) {
        const auto captureMode = qEnvironmentVariable("PEDRO_CAPTURE_MODE");

        const auto captureFilesWindow = captureMode == QStringLiteral("files-window");
        const auto capturePreview = captureMode == QStringLiteral("preview");
        const auto captureDesktop = captureMode == QStringLiteral("desktop");

        if (captureFilesWindow) {
            QMetaObject::invokeMethod(applicationController, "openFilesQuickWindow");
        } else if (!captureDesktop && !capturePreview) {
            applicationController->setProperty("panelMode", captureMode.isEmpty() ? QStringLiteral("quick") : captureMode);
        }

        bool hasCaptureAnchor = false;

        const auto captureAnchor = qEnvironmentVariable("PEDRO_CAPTURE_ANCHOR").toDouble(&hasCaptureAnchor);

        if (hasCaptureAnchor) {
            applicationController->setProperty("panelAnchorX", captureAnchor);
        }

        QTimer::singleShot(1000, &app, [window, capturePath, captureFilesWindow, capturePreview] {
            auto* captureWindow = window;

            if (captureFilesWindow || capturePreview) {
                for (auto* candidate : QGuiApplication::allWindows()) {
                    if (candidate->objectName() == (capturePreview ? QStringLiteral("previewWindow") : QStringLiteral("filesQuickWindow"))) {
                        captureWindow = qobject_cast<QQuickWindow*>(candidate);

                        break;
                    }
                }
            }

            QCoreApplication::exit(captureWindow && captureWindow->grabWindow().save(capturePath) ? 0 : 1);
        });
    }

    return QGuiApplication::exec();
}
