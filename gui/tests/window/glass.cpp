#include "../../backend/icons.hpp"

#include <QGuiApplication>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QQmlContext>
#include <QQmlPropertyMap>
#include <QQuickWindow>
#include <QTimer>
#include <QImage>
#include <QDebug>

int main(int argc, char** argv) {
    QGuiApplication app(argc, argv);
    QQmlPropertyMap backend;
    backend.insert("appearanceMode", "dark");
    backend.insert("wallpaper", QUrl{});
    QQmlEngine engine;
    engine.addImageProvider("icons", new Icons);
    engine.rootContext()->setContextProperty("Backend", &backend);
    QQmlComponent lowerComponent(&engine);
    lowerComponent.setData("import QtQuick; Window { width: 500; height: 400; Rectangle { anchors.fill: parent; color: 'red' } }", QUrl());
    auto* lower = qobject_cast<QQuickWindow*>(lowerComponent.create());
    QQmlComponent component(&engine, QUrl::fromLocalFile(QString::fromLocal8Bit(argv[1])));
    auto* frame = qobject_cast<QQuickWindow*>(component.create());
    if (!frame || !lower) {
        qCritical() << component.errors() << lowerComponent.errors();
        return 1;
    }
    lower->setPosition(100, 100);
    frame->setPosition(100, 100);
    frame->setProperty("backdropWindows", QVariantList{QVariant::fromValue(lower)});
    lower->show();
    frame->show();
    frame->raise();
    QTimer::singleShot(1000, &app, [&] {
        const auto overlap = frame->grabWindow().pixelColor(200, 200);
        for (auto* child : lower->findChildren<QObject*>()) {
            if (child->property("color").isValid())
                child->setProperty("color", QColor("blue"));
        }
        QTimer::singleShot(500, &app, [&, overlap] {
            const auto changed = frame->grabWindow().pixelColor(200, 200);
            lower->setPosition(1100, 100);
            QTimer::singleShot(500, &app, [&, overlap, changed] {
                const auto outside = frame->grabWindow().pixelColor(200, 200);
                const bool passed = overlap.red() > overlap.green() + 40 && changed.blue() > changed.red() + 40 && qAbs(outside.red() - outside.green()) < 40;
                qInfo() << "Lower window glass:" << overlap << "updated content:" << changed << "after moving away:" << outside << (passed ? "PASSED" : "FAILED");
                app.exit(passed ? 0 : 2);
            });
        });
    });
    return app.exec();
}
