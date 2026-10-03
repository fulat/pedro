#include "gui/backend/icons.hpp"

#include <QGuiApplication>
#include <QQmlComponent>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQuickItem>
#include <QQuickWindow>
#include <QTest>

#include <iostream>
#include <memory>

class Capture final : public QObject {
        Q_OBJECT
        Q_PROPERTY(bool visible MEMBER shown NOTIFY changed)
        Q_PROPERTY(bool busy MEMBER busy CONSTANT)
        Q_PROPERTY(bool recording MEMBER recording CONSTANT)
        Q_PROPERTY(QString error MEMBER error CONSTANT)

    public:

        bool shown = true;
        bool busy = false;
        bool recording = false;
        QString error;
        QRect captured;

        Q_INVOKABLE void close() {
            shown = false;
            emit changed();
        }

        Q_INVOKABLE void take(const QRect& area, bool, bool, int) {
            captured = area;
        }

    signals:
        void changed();
};

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
    Capture manager;
    Backend backend;
    backend.capture = &manager;
    qputenv("PEDRO_QML_DIR", argv[2]);
    QQmlEngine engine;
    engine.addImageProvider("icons", new Icons);
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
    item->setProperty("screenGeometry", QRectF(-100, 0, 1920, 1080));
    item->setProperty("screenOrigin", QPointF(35, 45));
    item->setProperty("area", false);
    QMetaObject::invokeMethod(item.get(), "submit");
    if (manager.captured != QRect(-100, 0, 1920, 1080)) {
        return 1;
    }
    item->setProperty("area", true);
    item->setProperty("region", QRectF(250, 175, 500, 350));
    QMetaObject::invokeMethod(item.get(), "submit");
    if (manager.captured != QRect(285, 220, 500, 350)) {
        return 1;
    }
    auto* toolbar = item->findChild<QQuickItem*>("captureToolbar");
    const auto original = toolbar->position();
    const QPoint from(qRound(original.x() + 38), qRound(original.y() + 20));
    QTest::mousePress(&window, Qt::LeftButton, Qt::NoModifier, from);
    QTest::mouseMove(&window, from - QPoint(20, 20), 10);
    QTest::mouseMove(&window, from - QPoint(120, 80), 10);
    QTest::mouseRelease(&window, Qt::LeftButton, Qt::NoModifier, from - QPoint(120, 80));
    if (toolbar->x() >= original.x() || toolbar->y() >= original.y()) {
        std::cerr << "FAIL: toolbar drag\n";
        return 1;
    }
    QTest::keyClick(&window, Qt::Key_Escape);
    if (manager.shown) {
        return 1;
    }
    std::cout << "PASS: all four edges, corner resizing, moving and minimum selection size, monitor geometry, toolbar drag and Escape\n";
}

#include "resize.moc"
