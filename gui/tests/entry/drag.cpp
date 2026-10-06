#include "entry/drag/image.h"

#include <QGuiApplication>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QQuickItem>
#include <QQuickWindow>
#include <QtTest>

#include <iostream>
#include <memory>

int main(int argc, char** argv) {
    QGuiApplication app(argc, argv);
    QQmlEngine engine;
    QQuickWindow window;
    window.resize(220, 180);
    QQmlComponent component(&engine);
    component.setData("import QtQuick\nRectangle { width: 64; height: 64; color: '#4088ff' }", QUrl());
    std::unique_ptr<QObject> object(component.create());
    auto* item = qobject_cast<QQuickItem*>(object.get());
    if (!item) {
        std::cerr << component.errorString().toStdString();
        return 1;
    }
    item->setParentItem(window.contentItem());
    window.show();
    if (!QTest::qWaitForWindowExposed(&window)) {
        return 2;
    }
    QTest::qWait(100);
    const auto preview = Pedro::Gui::Backend::Entry::Drag::image(item);
    if (preview.isNull() || preview.toImage().pixelColor(10, 10).alpha() < 200 || preview.toImage().pixelColor(10, 10).alpha() >= 255) {
        std::cerr << "Native drag preview missing or not translucent: null=" << preview.isNull() << " alpha=" << (preview.isNull() ? -1 : preview.toImage().pixelColor(10, 10).alpha()) << "\n";
        return 3;
    }
    item->setWidth(200);
    const auto wide = Pedro::Gui::Backend::Entry::Drag::image(item);
    if (wide.isNull() || wide.deviceIndependentSize().width() > 141) {
        return 4;
    }
    if (!Pedro::Gui::Backend::Entry::Drag::image(nullptr).isNull()) {
        return 5;
    }
    std::cout << "PASS: Qt Quick drag snapshot, transparency and bounded size\n";
    return 0;
}
