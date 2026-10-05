#include <pedro/papi/io/content/icon.h>
#include <pedro/papi/io/directory/model.hpp>
#include <pedro/papi/io/desktop/model.hpp>

#include "../../backend/icons.hpp"

#include <QDir>
#include <QElapsedTimer>
#include <QFile>
#include <QGuiApplication>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QQmlContext>
#include <QQmlPropertyMap>
#include <QQuickItem>
#include <QQuickWindow>
#include <QThread>

#include <iostream>

namespace {

    void require(bool condition, const char* message) {
        if (!condition) {
            std::cerr << message << '\n';
            std::exit(1);
        }
    }

    template <typename Predicate> void waitFor(Predicate predicate) {
        QElapsedTimer timer;
        timer.start();
        while (!predicate() && timer.elapsed() < 5000) {
            QCoreApplication::processEvents();
            QThread::msleep(5);
        }
        require(predicate(), "Timed out waiting for model or image");
    }

    void write(const QString& path, const QByteArray& data) {
        QDir().mkpath(QFileInfo(path).path());
        QFile file(path);
        require(file.open(QIODevice::WriteOnly), "Cannot write fixture");
        file.write(data);
    }

    void png(const QString& path, const QColor& color) {
        QDir().mkpath(QFileInfo(path).path());
        QImage image(64, 64, QImage::Format_ARGB32);
        image.fill(color);
        require(image.save(path), "Cannot save icon fixture");
    }

}

int main(int argc, char** argv) {
    QGuiApplication app(argc, argv);
    const QString root = QString::fromLocal8Bit(argv[1]);
    const QString source = QString::fromLocal8Bit(argv[2]);
    using Pedro::Papi::Io::Content::iconNames;
    require(iconNames("application/pdf").contains("application-pdf"), "PDF names must come from GIO");
    require(iconNames("application/zip").contains("application-zip"), "ZIP names must come from GIO");
    require(iconNames("text/x-python").contains("text-x-python"), "Code names must come from GIO");
    require(iconNames({}).last() == "text-x-generic", "Unknown types must have a generic fallback");

    const auto files = root + "/desktop";
    QDir().mkpath(files + "/Folder");
    write(files + "/test.pdf", "%PDF-1.4\n");
    write(files + "/test.zip", QByteArray("PK\003\004", 4));
    write(files + "/test.py", "#!/usr/bin/python3\nprint('test')\n");
    write(files + "/unknown", QByteArray("\0\1\2\3", 4));
    png(files + "/image.png", Qt::yellow);
    Pedro::Papi::Io::Directory::Model directory;
    directory.open(QUrl::fromLocalFile(files).toString());
    waitFor([&] { return !directory.loading() && directory.rowCount() == 6; });
    Pedro::Papi::Io::Desktop::Model desktop;
    waitFor([&] { return !desktop.loading() && desktop.rowCount() == 6; });
    QVariantMap pdfEntry;
    for (auto* model : {static_cast<QAbstractItemModel*>(&directory), static_cast<QAbstractItemModel*>(&desktop)}) {
        for (int row = 0; row < model->rowCount(); ++row) {
            const auto entry = model->data(model->index(row, 0), Qt::UserRole + 1).toMap();
            const auto name = entry.value("name").toString();
            const auto names = entry.value("iconNames").toStringList();
            require(!names.isEmpty() && !entry.value("contentType").toString().isEmpty(), "Both models must expose GIO content type and candidate names");
            if (name == "Folder") {
                require(entry.value("visualType") == "folder", "Folder representation must remain special");
            } else if (name == "image.png") {
                require(entry.value("visualType") == "image", "Local image thumbnail must remain enabled");
            } else {
                const auto expected = name == "test.pdf" || name == "test.py" ? "document" : "themed";
                require(entry.value("visualType") == expected, "Document artwork and MIME theme fallback classification");
                if (name == "test.pdf") {
                    pdfEntry = entry;
                    require(names.contains("application-pdf"), "Actual PDF must expose its specific GIO icon");
                }
                if (name == "test.zip") {
                    require(names.contains("application-zip"), "Actual ZIP must expose its specific GIO icon");
                }
            }
        }
    }

    const auto themes = root + "/themes";
    QByteArray index = "[Icon Theme]\nName=Pedro\nInherits=Yaru,hicolor\nDirectories=scalable/mimetypes\n[scalable/mimetypes]\nSize=64\nType=Scalable\nMinSize=8\nMaxSize=512\nContext=MimeTypes\n";
    write(themes + "/Pedro/index.theme", index);
    write(themes + "/Yaru/index.theme", index.replace("Name=Pedro", "Name=Yaru").replace("Inherits=Yaru,hicolor", "Inherits=hicolor"));
    write(themes + "/hicolor/index.theme", "[Icon Theme]\nName=hicolor\nDirectories=scalable/mimetypes\n[scalable/mimetypes]\nSize=64\nType=Scalable\nMinSize=8\nMaxSize=512\nContext=MimeTypes\n");
    const auto svg = themes + "/Pedro/scalable/mimetypes/application-pdf.svg";
    write(svg, "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 64 64'><rect width='64' height='64' fill='#ff0000'/></svg>");
    const auto generic = themes + "/Pedro/scalable/mimetypes/text-x-generic.svg";
    QDir().mkpath(QFileInfo(generic).path());
    QFile::remove(generic);
    require(QFile::copy(source + "/gnome/appearance/icons/Pedro/scalable/mimetypes/text-x-generic.svg", generic), "Cannot copy generic fixture");
    png(themes + "/Yaru/scalable/mimetypes/application-pdf.png", Qt::blue);
    png(themes + "/Yaru/scalable/mimetypes/application-zip.png", Qt::blue);
    png(themes + "/Yaru/scalable/mimetypes/text-x-python.png", Qt::blue);
    png(themes + "/hicolor/scalable/mimetypes/probe.png", Qt::green);
    QIcon::setThemeSearchPaths({themes});
    QIcon::setThemeName("Pedro");
    QIcon::setFallbackThemeName("hicolor");
    Icons provider;
    auto image = [&](const QStringList& names) {
        QJsonArray array;
        for (const auto& name : names) {
            array.append(name);
        }
        QSize size;
        const auto id = "theme/" + QString::fromUtf8(QUrl::toPercentEncoding(QString::fromUtf8(QJsonDocument(array).toJson(QJsonDocument::Compact))));
        const auto result = provider.requestImage(id, &size, QSize(64, 64));
        require(!result.isNull(), "Themed provider must always produce an image");
        return result;
    };
    require(image(iconNames("application/pdf")).pixelColor(32, 32) == QColor(Qt::red), "Pedro SVG must override inherited MIME icon");
    QFile::remove(svg);
    QIcon::setThemeName("reset");
    QIcon::setThemeName("Pedro");
    require(image(iconNames("application/pdf")).pixelColor(32, 32) == QColor(Qt::blue), "Missing Pedro PDF must inherit Yaru");
    require(image(iconNames("application/zip")).pixelColor(32, 32) == QColor(Qt::blue), "ZIP must resolve through inherited theme");
    require(image(iconNames("text/x-python")).pixelColor(32, 32) == QColor(Qt::blue), "Code must resolve without extension mappings");
    require(image({"missing", "probe"}).pixelColor(32, 32) == QColor(Qt::green), "Ordered names must reach hicolor");
    require(image({"totally-unknown"}).pixelColor(32, 32).alpha() > 0, "Unknown type must render Pedro generic fallback");

    qputenv("PEDRO_QML_DIR", (source + "/gui").toUtf8());
    QQmlEngine engine;
    engine.addImageProvider("icons", new Icons);
    auto verifyQml = [&](const QString& properties) {
        QQmlComponent component(&engine);
        const auto qml = "import QtQuick\nimport \"" + QUrl::fromLocalFile(source + "/gui/qml/components/desktop").toString() + "\" as Desktop\nDesktop.Icon { width: 64; height: 64; " + properties + " }";
        component.setData(qml.toUtf8(), QUrl());
        auto* item = component.create();
        require(item != nullptr, "Shared QML icon component must load");
        bool loaded = false;
        for (auto* child : item->findChildren<QObject*>()) {
            if (child->property("status").isValid() && child->property("source").toUrl().isValid() && !child->property("source").toUrl().isEmpty()) {
                waitFor([&] { return child->property("status").toInt() == 1; });
                loaded = true;
            }
        }
        require(loaded, "QML icon must load a real themed image or thumbnail");
        delete item;
    };
    verifyQml("kind: 'themed'; iconNames: ['application-pdf']");
    verifyQml("kind: 'image'; imageUrl: '" + QUrl::fromLocalFile(files + "/image.png").toString() + "'");
    engine.rootContext()->setContextProperty("Backend", QVariantMap{{"appearanceMode", "dark"}});
    QQmlPropertyMap navigation;
    navigation.insert("directory", QVariant::fromValue<QObject*>(&directory));
    navigation.insert("selectedEntry", QVariantMap{});
    QQuickWindow window;
    window.resize(800, 600);
    window.show();
    QQuickItem host;
    host.setParentItem(window.contentItem());
    host.setWidth(800);
    host.setHeight(600);
    for (const auto& view : {"card", "table"}) {
        QQmlComponent component(&engine, QUrl::fromLocalFile(source + "/gui/qml/components/files/" + view + ".qml"));
        QVariantMap properties{{"parent", QVariant::fromValue<QObject*>(&host)}, {"controller", QVariant::fromValue<QObject*>(&navigation)}};
        if (QString(view) == "card") {
            properties.insert("entry", pdfEntry);
        }
        auto* item = component.createWithInitialProperties(properties);
        require(item != nullptr, "Card and table components must load");
        waitFor([&] {
            const auto loadedIcon = [](const auto& visit, QQuickItem* root) -> bool {
                if ((root->property("source").toUrl().toString().startsWith("image://icons/theme/") || root->property("source").toUrl().toString() == "image://icons/original/document.svg") && root->property("status").toInt() == 1) {
                    return true;
                }
                for (auto* child : root->childItems()) {
                    if (visit(visit, child)) {
                        return true;
                    }
                }
                return false;
            };
            return loadedIcon(loadedIcon, qobject_cast<QQuickItem*>(item));
        });
        delete item;
    }
    std::cout << "MIME icons: GIO models, Pedro SVG, inherited Yaru/hicolor, generic fallback and shared QML passed\n";
}
