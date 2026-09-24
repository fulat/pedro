#include "info.hpp"

#include <QDebug>
#include <QGuiApplication>
#include <QOpenGLContext>
#include <QOpenGLFunctions>
#include <QQuickWindow>
#include <QScreen>
#include <QSGRendererInterface>
#include <QTimer>

namespace Pedro::Gui::Render {

    namespace {

        QString value(const char* name) {

            const auto result = qEnvironmentVariable(name);

            return result.isNull() ? QStringLiteral("<unset>") : result;
        }

        QString apiName(QSGRendererInterface::GraphicsApi api) {

            switch (api) {
            case QSGRendererInterface::Software:
                return QStringLiteral("software");
            case QSGRendererInterface::OpenVG:
                return QStringLiteral("OpenVG");
            case QSGRendererInterface::OpenGL:
                return QStringLiteral("OpenGL/RHI");
            case QSGRendererInterface::Direct3D11:
                return QStringLiteral("Direct3D 11/RHI");
            case QSGRendererInterface::Vulkan:
                return QStringLiteral("Vulkan/RHI");
            case QSGRendererInterface::Metal:
                return QStringLiteral("Metal/RHI");
            case QSGRendererInterface::Null:
                return QStringLiteral("null");
            case QSGRendererInterface::Direct3D12:
                return QStringLiteral("Direct3D 12/RHI");
            default:
                return QStringLiteral("unknown");
            }
        }

        void logScreen(const QQuickWindow& window) {

            const auto* screen = window.screen();
            if (!screen) {
                qInfo() << "render.screen: unavailable";
                return;
            }

            qInfo() << "render.screen.name:" << screen->name();
            qInfo() << "render.screen.geometry:" << screen->geometry();
            qInfo() << "render.screen.available:" << screen->availableGeometry();
            qInfo() << "render.screen.devicePixelRatio:" << screen->devicePixelRatio();
            qInfo() << "render.screen.logicalDpi:" << screen->logicalDotsPerInch();
            qInfo() << "render.screen.physicalDpi:" << screen->physicalDotsPerInch();
            qInfo() << "render.screen.physicalSizeMm:" << screen->physicalSize();
            qInfo() << "render.window.logicalSize:" << window.size();
            qInfo() << "render.window.devicePixelRatio:" << window.devicePixelRatio();
            qInfo() << "render.window.effectiveDevicePixelRatio:" << window.effectiveDevicePixelRatio();
            qInfo() << "render.window.expectedPhysicalSize:" << QSizeF(window.width() * window.effectiveDevicePixelRatio(), window.height() * window.effectiveDevicePixelRatio());
        }

        void logEnvironment() {

            qInfo() << "render.platform:" << QGuiApplication::platformName();
            qInfo() << "render.session:" << value("XDG_SESSION_TYPE");
            qInfo() << "render.waylandDisplay:" << value("WAYLAND_DISPLAY");
            qInfo() << "render.x11Display:" << value("DISPLAY");
            qInfo() << "render.textRenderer:" << (QQuickWindow::textRenderType() == QQuickWindow::NativeTextRendering ? "native" : "qt");

            constexpr const char* overrides[] = {
                "QT_QPA_PLATFORM", "QT_SCALE_FACTOR", "QT_AUTO_SCREEN_SCALE_FACTOR", "QT_ENABLE_HIGHDPI_SCALING", "QT_SCREEN_SCALE_FACTORS", "QT_FONT_DPI", "QT_QUICK_BACKEND", "QSG_RHI_BACKEND",
            };

            for (const auto* name : overrides)
                qInfo().noquote() << QStringLiteral("render.env.%1: %2").arg(name, value(name));
        }

    }

    void Info::attach(QQuickWindow& window) {

        logEnvironment();
        logScreen(window);

        QObject::connect(&window, &QQuickWindow::screenChanged, &window, [&window] { logScreen(window); });

        QObject::connect(
            &window, &QQuickWindow::sceneGraphInitialized, &window,
            [&window] {
                const auto* renderer = window.rendererInterface();
                const auto api = renderer ? renderer->graphicsApi() : QSGRendererInterface::Unknown;
                qInfo() << "render.sceneGraph.api:" << apiName(api);

                if (api != QSGRendererInterface::OpenGL || !renderer)
                    return;

                auto* context = static_cast<QOpenGLContext*>(renderer->getResource(&window, QSGRendererInterface::OpenGLContextResource));
                if (!context)
                    context = QOpenGLContext::currentContext();
                if (!context)
                    return;

                auto* functions = context->functions();
                const auto text = [functions](GLenum name) {
                    const auto* result = functions->glGetString(name);
                    return result ? QString::fromLatin1(reinterpret_cast<const char*>(result)) : QStringLiteral("<unavailable>");
                };
                GLint viewport[4] = {};
                functions->glGetIntegerv(GL_VIEWPORT, viewport);

                qInfo() << "render.opengl.vendor:" << text(GL_VENDOR);
                qInfo() << "render.opengl.renderer:" << text(GL_RENDERER);
                qInfo() << "render.opengl.version:" << text(GL_VERSION);
                qInfo() << "render.opengl.viewport:" << QSize(viewport[2], viewport[3]);
            },
            Qt::DirectConnection);

        QTimer::singleShot(1000, &window, [&window] {
            const auto frame = window.grabWindow();
            qInfo() << "render.capture.pixelSize:" << frame.size();
            qInfo() << "render.capture.devicePixelRatio:" << frame.devicePixelRatio();
        });
    }

}
