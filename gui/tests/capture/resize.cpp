#include "papi/gui/capture/manager.h"

#include <QGuiApplication>
#include <QQmlComponent>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQuickItem>
#include <QQuickWindow>
#include <QTest>

#include <iostream>
#include <memory>

class Backend final : public QObject {
        Q_OBJECT
        Q_PROPERTY(QObject* capture MEMBER capture CONSTANT)
        Q_PROPERTY(QString appearanceMode MEMBER appearanceMode CONSTANT)

    public:

        QObject* capture = nullptr;
        QString appearanceMode = "dark";
};

int main(int argc, char** argv) {
    QGuiApplication application(argc, argv);
    Pedro::Papi::Gui::Capture::Manager manager;
    Backend backend;
    backend.capture = &manager;
    QQmlEngine engine;
    engine.rootContext()->setContextProperty("Backend", &backend);
    QQmlComponent component(&engine, QUrl::fromLocalFile(QString::fromLocal8Bit(argv[1])));
    QQuickWindow window;
    window.resize(1000, 700);
    std::unique_ptr<QQuickItem> item(qobject_cast<QQuickItem*>(component.create()));
    if (!item) {
        std::cerr << component.errorString().toStdString();
        return 1;
    }
    item->setParentItem(window.contentItem());
    item->setWidth(1000);
    item->setHeight(700);
    manager.open();
    window.show();
    QTest::qWait(50);

    const auto drag = [&](QPoint from, QPoint to, QRectF expected) {
        item->setProperty("region", QRectF(250, 175, 500, 350));
        application.processEvents();
        QTest::mousePress(&window, Qt::LeftButton, Qt::NoModifier, from);
        QTest::mouseMove(&window, to, 10);
        QTest::mouseRelease(&window, Qt::LeftButton, Qt::NoModifier, to);
        application.processEvents();
        const auto result = item->property("region").toRectF();
        if (result != expected) {
            std::cerr << "FAIL: drag " << from.x() << "," << from.y() << " to " << to.x() << "," << to.y() << ": " << result.x() << "," << result.y() << "," << result.width() << "," << result.height() << '\n';
            return false;
        }
        return true;
    };
    if (!drag({250, 350}, {200, 350}, {200, 175, 550, 350}) || !drag({750, 350}, {800, 350}, {250, 175, 550, 350}) || !drag({500, 175}, {500, 125}, {250, 125, 500, 400}) || !drag({500, 525}, {500, 575}, {250, 175, 500, 400}) || !drag({250, 175}, {200, 125}, {200, 125, 550, 400}) || !drag({500, 350}, {525, 380}, {275, 205, 500, 350}) || !drag({250, 350}, {740, 350}, {726, 175, 24, 350})) {
        return 1;
    }
    std::cout << "PASS: all four edges, corner resizing, moving and minimum selection size\n";
}

#include "resize.moc"
