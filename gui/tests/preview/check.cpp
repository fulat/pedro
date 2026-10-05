#include <pedro/papi/gui/preview/manager.h>
#include <pedro/papi/io/thumbnail/image.h>
#include <pedro/papi/gui/preview/text/provider.h>

#include "preview/provider.h"
#include "icons.hpp"

#include <QDir>
#include <QElapsedTimer>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QMimeDatabase>
#include <QProcess>
#include <QQmlComponent>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQmlProperty>
#include <QQuickItem>
#include <QThread>

#include <cairo-pdf.h>

#include <cmath>
#include <iostream>
#include <memory>

namespace Pedro::Gui::Tests::Preview {

    class Backend : public QObject {
            Q_OBJECT
            Q_PROPERTY(QString appearanceMode READ appearanceMode CONSTANT)
            Q_PROPERTY(QString wallpaper READ wallpaper CONSTANT)
            Q_PROPERTY(QObject* preview READ preview CONSTANT)

        public:

            explicit Backend(Papi::Gui::Preview::Manager& manager) : manager(manager) {
            }

            QString appearanceMode() const {
                return QStringLiteral("dark");
            }

            QString wallpaper() const {
                return {};
            }

            QObject* preview() {
                return &manager;
            }

        private:

            Papi::Gui::Preview::Manager& manager;
    };

}

int main(int argc, char** argv) {

    QGuiApplication app(argc, argv);
    app.setQuitOnLastWindowClosed(false);

    if (argc != 4) {
        std::cerr << "Usage: check preview/window.qml build/fixtures /path/to/ffmpeg\n";
        return 1;
    }

    const QDir fixtures(QString::fromLocal8Bit(argv[2]));
    QDir().mkpath(fixtures.path());
    const auto path = [&fixtures](const QString& name) { return fixtures.filePath(name); };
    const auto url = [&path](const QString& name) { return QUrl::fromLocalFile(path(name)); };
    const auto write = [&path](const QString& name, const QByteArray& bytes) {
        QFile file(path(name));
        return file.open(QIODevice::WriteOnly) && file.write(bytes) == bytes.size();
    };
    QImage image(32, 24, QImage::Format_RGBA8888);
    image.fill(Qt::red);

    if (!image.save(path("image.png")) || !write("source.cpp", "#include <iostream>\n<script>literal text</script>\n") || !write("binary.bin", QByteArray(256, '\0')) || !write("broken.png", "invalid image") || !write("large.txt", QByteArray(2 * 1024 * 1024, 'x'))) {
        return 2;
    }

    auto* surface = cairo_pdf_surface_create(path("document.pdf").toLocal8Bit().constData(), 200, 300);
    auto* context = cairo_create(surface);
    cairo_set_source_rgb(context, 1, 0, 0);
    cairo_paint(context);
    cairo_show_page(context);
    cairo_set_source_rgb(context, 0, 0, 1);
    cairo_paint(context);
    cairo_show_page(context);
    cairo_destroy(context);
    cairo_surface_destroy(surface);

    QProcess ffmpeg;
    ffmpeg.start(QString::fromLocal8Bit(argv[3]), {"-hide_banner", "-loglevel", "error", "-f", "lavfi", "-i", "testsrc2=size=160x90:rate=24", "-t", "3", "-c:v", "mpeg4", "-y", path("video.mp4")});

    if (!ffmpeg.waitForFinished(30000) || ffmpeg.exitCode() != 0) {
        std::cerr << ffmpeg.readAllStandardError().constData();
        return 3;
    }

    ffmpeg.start(QString::fromLocal8Bit(argv[3]), {"-hide_banner", "-loglevel", "error", "-i", path("video.mp4"), "-vf", "scale=90:640,setsar=1", "-c:v", "mpeg4", "-y", path("portrait.mp4")});

    if (!ffmpeg.waitForFinished(30000) || ffmpeg.exitCode() != 0) {
        return 31;
    }

    ffmpeg.start(QString::fromLocal8Bit(argv[3]), {"-hide_banner", "-loglevel", "error", "-f", "lavfi", "-i", "sine=frequency=440", "-t", "3", "-y", path("audio.wav")});

    if (!ffmpeg.waitForFinished(30000) || ffmpeg.exitCode() != 0) {
        return 4;
    }

    qputenv("XDG_CACHE_HOME", fixtures.filePath("cache").toUtf8());
    const auto thumbnail = Pedro::Papi::Io::Thumbnail::image(url("video.mp4"));
    const auto cachedThumbnail = Pedro::Papi::Io::Thumbnail::image(url("video.mp4"));

    if (thumbnail.isNull() || thumbnail.width() > 256 || thumbnail.height() > 256 || thumbnail != cachedThumbnail || !Pedro::Papi::Io::Thumbnail::image(url("missing.mp4")).isNull()) {
        std::cerr << "GNOME video thumbnail generation and cached lookup failed\n";
        return 42;
    }

    const auto thumbnailPath = path("thumbnail with spaces.mp4");
    QFile::remove(thumbnailPath);
    QFile::copy(path("video.mp4"), thumbnailPath);
    const auto thumbnailUrl = QUrl::fromLocalFile(thumbnailPath);
    const auto before = Pedro::Papi::Io::Thumbnail::image(thumbnailUrl);
    QFile thumbnailFile(thumbnailPath);
    const auto modified = QFileInfo(thumbnailPath).lastModified().addSecs(5);

    if (before.isNull() || !thumbnailFile.open(QIODevice::ReadWrite) || !thumbnailFile.setFileTime(modified, QFileDevice::FileModificationTime)) {
        return 43;
    }

    thumbnailFile.close();
    const auto refreshed = Pedro::Papi::Io::Thumbnail::image(thumbnailUrl);

    if (refreshed.isNull() || refreshed.text(QStringLiteral("Thumb::MTime")) != QString::number(modified.toSecsSinceEpoch())) {
        std::cerr << "GNOME thumbnail cache invalidation failed\n";
        return 44;
    }

    QObject previewOwner;
    Pedro::Papi::Gui::Preview::Manager manager(&previewOwner);
    manager.setObjectName(QStringLiteral("first"));
    Pedro::Gui::Tests::Preview::Backend backend(manager);
    QQmlEngine engine;
    engine.rootContext()->setContextProperty("Backend", &backend);
    qputenv("PEDRO_QML_DIR", QFileInfo(QString::fromLocal8Bit(argv[1])).dir().filePath("../../..").toUtf8());
    engine.addImageProvider("icons", new Icons);
    engine.addImageProvider("preview", new Pedro::Gui::Backend::Preview::Provider(previewOwner));
    QStringList warnings;
    QObject::connect(&engine, &QQmlEngine::warnings, &app, [&warnings](const QList<QQmlError>& errors) {
        for (const auto& error : errors) {
            warnings.append(error.toString());
        }
    });
    QQmlComponent component(&engine, QUrl::fromLocalFile(QString::fromLocal8Bit(argv[1])));
    std::unique_ptr<QObject> loader(component.create());

    if (!loader) {
        std::cerr << component.errorString().toStdString();
        return 5;
    }

    QObject::connect(&manager, &Pedro::Papi::Gui::Preview::Manager::opened, loader.get(), [&loader] { QMetaObject::invokeMethod(loader.get(), "open"); });
    const auto waitFor = [&app](const auto& condition) {
        QElapsedTimer elapsed;
        elapsed.start();

        while (!condition() && elapsed.elapsed() < 10000) {
            app.processEvents();
            QThread::msleep(10);
        }

        return condition();
    };
    const auto ready = [&manager, &waitFor] { return waitFor([&manager] { return !manager.busy(); }) && manager.error().isEmpty(); };
    const auto require = [&manager](bool passed, const char* message) {
        if (!passed) {
            std::cerr << message << ": " << manager.error().toStdString() << '\n';
        }
        return passed;
    };

    Pedro::Papi::Gui::Preview::Registry registry;
    registry.add({"image/png"}, [] { return std::make_unique<Pedro::Papi::Gui::Preview::Text::Provider>(); });

    if (!require(registry.create(QMimeDatabase().mimeTypeForName("image/png"))->state().kind == "text", "Exact provider registration before image family")) {
        return 24;
    }

    manager.setVolume(0.4);
    manager.setMuted(true);
    manager.open(url("image.png"), {url("image.png"), url("source.cpp"), url("document.pdf")});

    if (!require(ready() && manager.kind() == "image" && manager.frameSize() == QSize(32, 24) && manager.canNext() && !manager.canPrevious() && std::abs(manager.volume() - 0.4) < 0.001 && manager.muted(), "Image provider")) {
        return 6;
    }

    auto* window = QQmlProperty::read(loader.get(), "item").value<QObject*>();
    auto* view = window ? QQmlProperty::read(window, "contentItem").value<QObject*>() : nullptr;
    auto* previewSurface = view ? view->findChild<QObject*>("previewSurface") : nullptr;

    if (!require(previewSurface && waitFor([&] { return previewSurface->property("status").toInt() == 1 && window->property("visible").toBool(); }), "QML surface")) {
        return 7;
    }

    const auto contentWidth = window->property("width").toDouble() - 2 * window->property("contentMargin").toDouble();
    const auto contentHeight = window->property("height").toDouble() - window->property("headerHeight").toDouble() - window->property("contentTopGap").toDouble() - window->property("contentMargin").toDouble();

    if (!require(std::abs(contentWidth / contentHeight - 32.0 / 24.0) < 0.01, "Image window aspect ratio")) {
        return 27;
    }

    auto* zoomIn = window->findChild<QObject*>("previewZoomIn");
    auto* rotate = window->findChild<QObject*>("previewRotate");
    auto* information = window->findChild<QObject*>("previewInformation");
    auto* informationPopup = window->findChild<QObject*>("previewInformationPopup");

    if (!require(zoomIn && rotate && information && informationPopup, "Image toolbar")) {
        return 25;
    }

    QMetaObject::invokeMethod(zoomIn, "clicked");
    QMetaObject::invokeMethod(rotate, "clicked");
    QMetaObject::invokeMethod(information, "clicked");

    if (!require(view->property("zoom").toDouble() > 1 && view->property("rotationAngle").toInt() == 90 && informationPopup->property("visible").toBool(), "Image toolbar actions")) {
        return 26;
    }

    QMetaObject::invokeMethod(informationPopup, "close");

    manager.next();

    if (!require(ready() && manager.kind() == "text" && manager.text().contains("<script>literal text</script>") && manager.canPrevious(), "Text provider and next")) {
        return 8;
    }

    auto* text = view->findChild<QObject*>("previewText");

    if (!text || text->property("textFormat").toInt() != 0 || text->property("readOnly").toBool()) {
        return 9;
    }

    auto* toolbar = view->findChild<QObject*>("previewToolbar");
    if (!require(toolbar && !toolbar->property("visible").toBool(), "Text preview has no toolbar")) {
        return 42;
    }

    text->setProperty("text", QStringLiteral("Edited document\n"));
    QCoreApplication::processEvents();
    if (!require(!text->property("readOnly").toBool() && !view->property("dirty").toBool() && manager.text() == "Edited document\n", "Immediate Qt text editing and autosave")) {
        return 34;
    }
    QFile saved(manager.source().toLocalFile());
    if (!saved.open(QIODevice::ReadOnly))
        return 35;
    if (!require(saved.readAll() == "Edited document\n", "Saved text content")) {
        return 35;
    }
    saved.close();
    if (!saved.open(QIODevice::WriteOnly))
        return 36;
    saved.write("External change");
    saved.close();
    if (!require(!manager.saveText("Overwrite") && !manager.saveError().isEmpty(), "External edit conflict")) {
        return 36;
    }
    text->setProperty("text", QStringLiteral("Unsaved local change"));
    QVariant canClose = true;
    QMetaObject::invokeMethod(view, "requestClose", Q_RETURN_ARG(QVariant, canClose));
    if (!require(!canClose.toBool() && text->property("text").toString() == "Unsaved local change", "Failed autosave retains draft and blocks close")) {
        return 37;
    }

    manager.next();

    if (!require(ready() && manager.kind() == "document" && manager.pageCount() == 2 && manager.frame().pixelColor(100, 100).red() > 240, "PDF provider")) {
        return 10;
    }

    manager.setPage(1);

    if (!require(ready() && manager.page() == 1 && manager.frame().pixelColor(100, 100).blue() > 240, "PDF navigation")) {
        return 11;
    }

    manager.previous();

    if (!require(ready() && manager.kind() == "text", "Previous file")) {
        return 12;
    }

    manager.open(url("large.txt"));

    if (!require(ready() && manager.text().size() < 128 * 1024 + 100 && manager.textTruncated() && !manager.editable() && !manager.saveText("Overwrite"), "Bounded text preview")) {
        return 13;
    }

    QFile encoded(url("encoded.txt").toLocalFile());
    if (!encoded.open(QIODevice::WriteOnly))
        return 38;
    encoded.write(QByteArray::fromHex("efbbbf") + "First\r\nSecond\r\n");
    encoded.close();
    manager.open(url("encoded.txt"));
    if (!require(ready() && manager.editable() && manager.saveText("Changed\nSecond\n"), "Encoded text save"))
        return 38;
    if (!encoded.open(QIODevice::ReadOnly))
        return 38;
    if (!require(encoded.readAll() == QByteArray::fromHex("efbbbf") + "Changed\r\nSecond\r\n", "Preserved BOM and CRLF"))
        return 39;
    encoded.close();
    if (!require(manager.saveText("") && manager.saveText(QString::fromUtf8("é\n")), "Empty UTF-8 document round trip"))
        return 39;
    if (!encoded.open(QIODevice::ReadOnly))
        return 39;
    if (!require(encoded.readAll() == QByteArray::fromHex("efbbbfc3a90d0a"), "Preserved BOM and CRLF after clearing document"))
        return 39;
    encoded.close();

    if (!encoded.open(QIODevice::WriteOnly | QIODevice::Truncate))
        return 39;
    encoded.write(QByteArray::fromHex("fffe41000a00"));
    encoded.close();
    manager.open(url("encoded.txt"));
    if (!require(ready() && manager.saveText("") && manager.saveText(QString::fromUtf8("é")), "Empty UTF-16 document round trip"))
        return 39;
    if (!encoded.open(QIODevice::ReadOnly))
        return 39;
    if (!require(encoded.readAll() == QByteArray::fromHex("fffee900"), "Preserved UTF-16 encoding after clearing document"))
        return 39;
    encoded.close();

    for (const auto& name : {QStringLiteral("empty"), QStringLiteral("noextension")}) {
        QFile extensionless(url(name).toLocalFile());
        if (!extensionless.open(QIODevice::WriteOnly))
            return 40;
        if (name == "noextension")
            extensionless.write("Plain content without extension");
        extensionless.close();
        manager.open(url(name));
        if (!require(ready() && manager.kind() == "text" && manager.editable(), "Extensionless and empty document detection"))
            return 40;
        text->setProperty("text", QStringLiteral("Autosaved extensionless document"));
        if (!require(manager.text() == "Autosaved extensionless document" && !view->property("dirty").toBool(), "Extensionless autosave"))
            return 41;
    }

    manager.open(url("binary.bin"));

    if (!require(waitFor([&] { return !manager.busy(); }) && manager.kind() == "unsupported" && !manager.error().isEmpty(), "Unsupported fallback")) {
        return 14;
    }

    manager.open(url("broken.png"));

    if (!require(waitFor([&] { return !manager.busy(); }) && !manager.error().isEmpty(), "Corrupt image")) {
        return 15;
    }

    // A superseded async request must never overwrite the newly selected file.
    manager.open(url("document.pdf"));
    manager.open(url("source.cpp"));

    if (!require(ready() && manager.kind() == "text" && manager.name() == "source.cpp", "Superseded load")) {
        return 16;
    }

    manager.open(url("video.mp4"));

    if (!require(waitFor([&] { return !manager.busy() && !manager.frame().isNull() && !manager.playing() && manager.position() < 100; }) && manager.kind() == "video", "GStreamer video")) {
        std::cerr << "busy=" << manager.busy() << " playing=" << manager.playing() << " pos=" << manager.position() << " null=" << manager.frame().isNull() << " kind=" << manager.kind().toStdString() << "\n";
        return 17;
    }

    if (!require(waitFor([&] { return window->property("visible").toBool() && !loader->property("pendingOpen").toBool(); }), "Video window shown after frame readiness")) {
        return 41;
    }

    const auto videoWidth = window->property("width").toDouble() - 2 * window->property("contentMargin").toDouble();
    const auto videoHeight = window->property("height").toDouble() - window->property("headerHeight").toDouble() - window->property("contentMargin").toDouble();

    if (!require(window->property("headerHeight").toInt() == 34 && std::abs(videoWidth / videoHeight - 160.0 / 90.0) < 0.02, "Compact video window and thin title bar")) {
        return 30;
    }

    if (!require(view->findChild<QObject*>("previewVideoOverlay") && !window->findChild<QObject*>("previewVideoSettings"), "Minimal video controls")) {
        return 28;
    }

    manager.togglePlayback();

    if (!require(waitFor([&] { return manager.playing() && manager.position() > 200; }), "Explicit video play")) {
        return 29;
    }

    manager.togglePlayback();

    if (!require(waitFor([&] { return !manager.playing(); }), "Pause")) {
        return 18;
    }

    manager.seek(1500);

    if (!require(waitFor([&] { return manager.position() >= 1000; }), "Seeking")) {
        return 19;
    }

    manager.setMuted(true);
    manager.setVolume(0.25);
    manager.togglePlayback();

    if (!require(manager.muted() && std::abs(manager.volume() - 0.25) < 0.001 && waitFor([&] { return manager.playing(); }), "Audio controls and resume")) {
        return 20;
    }

    manager.open(url("portrait.mp4"));

    if (!require(waitFor([&] { return !manager.busy() && manager.frameSize() == QSize(90, 640) && !loader->property("pendingOpen").toBool(); }), "Portrait video frame")) {
        return 32;
    }

    const auto portraitWidth = window->property("width").toDouble() - 2 * window->property("contentMargin").toDouble();
    const auto portraitHeight = window->property("height").toDouble() - window->property("headerHeight").toDouble() - window->property("contentMargin").toDouble();

    if (!require(std::abs(portraitWidth / portraitHeight - 90.0 / 640.0) < 0.005, "Portrait window without side bars")) {
        return 33;
    }

    Pedro::Papi::Gui::Preview::Manager secondManager(&previewOwner);
    secondManager.setObjectName(QStringLiteral("second"));
    std::unique_ptr<QObject> secondLoader(component.createWithInitialProperties({{"preview", QVariant::fromValue<QObject*>(&secondManager)}, {"openingPosition", QPointF(176, 124)}}));

    if (!require(bool(secondLoader), "Independent preview loader")) {
        return 35;
    }

    secondManager.open(url("video.mp4"));
    QMetaObject::invokeMethod(secondLoader.get(), "open");

    if (!require(waitFor([&] { return !secondManager.busy() && !secondManager.frame().isNull() && !secondLoader->property("pendingOpen").toBool(); }), "Second preview frame")) {
        return 36;
    }

    auto* secondWindow = QQmlProperty::read(secondLoader.get(), "item").value<QObject*>();
    auto* secondView = QQmlProperty::read(secondWindow, "contentItem").value<QObject*>();
    auto* secondSurface = secondView->findChild<QObject*>("previewSurface");
    if (!require(secondWindow->property("x").toInt() == 176 && secondWindow->property("y").toInt() == 124, "Offset new preview position")) {
        std::cerr << "offset=" << secondWindow->property("x").toInt() << "," << secondWindow->property("y").toInt() << " size=" << secondWindow->property("width").toInt() << "," << secondWindow->property("height").toInt() << "\n";
        return 39;
    }

    secondWindow->setProperty("width", 500);
    secondWindow->setProperty("height", 350);
    QMetaObject::invokeMethod(secondLoader.get(), "activateViewer");

    if (!require(secondWindow->property("width").toInt() == 500 && secondWindow->property("height").toInt() == 350 && secondManager.source() == url("video.mp4"), "Focus preserves existing preview size and file")) {
        return 40;
    }

    secondManager.togglePlayback();

    if (!require(waitFor([&] { return secondManager.playing() && secondManager.position() > 200 && secondSurface->property("status").toInt() == 1; }) && !manager.playing() && manager.source() == url("portrait.mp4") && QQmlProperty::read(view, "preview").value<QObject*>() == &manager && QQmlProperty::read(secondView, "preview").value<QObject*>() == &secondManager, "Independent windows, frames and playback")) {
        return 37;
    }

    QMetaObject::invokeMethod(secondWindow, "close");

    if (!require(!secondManager.active() && manager.active(), "Closing one preview preserves the other")) {
        return 38;
    }

    manager.open(url("audio.wav"));

    if (!require(waitFor([&] { return manager.position() > 200; }) && manager.kind() == "audio" && manager.frame().isNull(), "GStreamer audio")) {
        return 21;
    }

    QMetaObject::invokeMethod(window, "close");

    if (!require(!manager.active() && !manager.playing() && !manager.busy() && manager.frame().isNull(), "Close cleanup")) {
        return 22;
    }

    manager.open(url("document.pdf"));
    manager.close();
    QElapsedTimer timer;
    timer.start();

    while (timer.elapsed() < 300) {
        app.processEvents();
        QThread::msleep(10);
    }

    if (!require(!manager.active() && manager.kind().isEmpty(), "Close during load") || !warnings.isEmpty()) {
        std::cerr << warnings.join('\n').toStdString();
        return 23;
    }

    std::cout << "Preview providers and Liquid window: images, PDF pages, text, audio/video, seeking, navigation, replacement and close passed\n";
}

#include "check.moc"
