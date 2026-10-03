#include <pedro/papi/io/desktop/model.hpp>
#include <QGuiApplication>
#include <QHash>
#include <QQmlComponent>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQmlPropertyMap>
#include <QElapsedTimer>
#include <QQuickItem>
#include <QJSValue>
#include <QThread>
#include <QUrl>
#include <iostream>

int main(int argc, char** argv) {
    QGuiApplication app(argc, argv);
    qmlRegisterSingletonType<QQmlPropertyMap>("gui", 1, 0, "Papi", [](QQmlEngine*, QJSEngine*) -> QQmlPropertyMap* {
        auto* papi = new QQmlPropertyMap;
        papi->insert("installedApplications", QVariantList{});
        papi->insert("pinnedApplications", QVariantList{});
        return papi;
    });
    Pedro::Papi::Io::Desktop::Model model;
    QElapsedTimer timer;
    timer.start();
    while (model.loading() && timer.elapsed() < 5000) {
        app.processEvents();
        QThread::msleep(5);
    }
    if (model.loading()) {
        return 1;
    }
    QQmlPropertyMap backend;
    backend.insert("desktopModel", QVariant::fromValue<QObject*>(&model));
    QQmlEngine engine;
    engine.rootContext()->setContextProperty("Backend", &backend);
    QQmlComponent component(&engine, QUrl::fromLocalFile(QString::fromLocal8Bit(argv[1])));
    auto* root = component.create();
    if (!root) {
        std::cerr << component.errorString().toStdString();
        return 2;
    }
    auto* controller = root->findChild<QObject*>("controller");
    if (!controller) {
        return 3;
    }
    model.setOrganization("free");
    QHash<QString, QPointF> manual;
    auto* repeater = root->findChild<QObject*>("repeater");
    for (int row = 0; row < model.rowCount(); ++row) {
        QQuickItem* item = nullptr;
        QMetaObject::invokeMethod(repeater, "itemAt", Q_RETURN_ARG(QQuickItem*, item), Q_ARG(int, row));
        const auto id = model.data(model.index(row), Qt::UserRole + 1).toMap().value("id").toString();
        const QPointF position(150 + row * 125, 220 + (row % 2) * 140);
        item->setX(position.x());
        item->setY(position.y());
        manual.insert(id, position);
    }
    for (const auto& key : {"size", "type", "type"}) {
        QMetaObject::invokeMethod(controller, "wallpaperAction", Q_ARG(QVariant, QVariant(key)));
        timer.restart();
        while (timer.elapsed() < 100) {
            app.processEvents();
            QThread::msleep(5);
        }
    }
    if (!model.sortKey().isEmpty()) {
        return 14;
    }
    for (int row = 0; row < model.rowCount(); ++row) {
        QQuickItem* item = nullptr;
        QMetaObject::invokeMethod(repeater, "itemAt", Q_RETURN_ARG(QQuickItem*, item), Q_ARG(int, row));
        const auto id = model.data(model.index(row), Qt::UserRole + 1).toMap().value("id").toString();
        if (QPointF(item->x(), item->y()) != manual.value(id)) {
            std::cerr << "Sort toggle failed to restore the original visual layout\n";
            return 15;
        }
    }
    for (const auto& mode : {"free", "grid"}) {
        model.setOrganization(mode);
        for (const auto& key : {"name", "type", "date", "size"}) {
            if (!QMetaObject::invokeMethod(controller, "wallpaperAction", Q_ARG(QVariant, QVariant(key)))) {
                return 4;
            }
            timer.restart();
            while (timer.elapsed() < 100) {
                app.processEvents();
                QThread::msleep(5);
            }
            double previousX = -1;
            double previousY = -1;
            for (int row = 0; row < model.rowCount(); ++row) {
                const auto entry = model.data(model.index(row), Qt::UserRole + 1).toMap();
                QQuickItem* item = nullptr;
                auto* repeater = root->findChild<QObject*>("repeater");
                if (!QMetaObject::invokeMethod(repeater, "itemAt", Q_RETURN_ARG(QQuickItem*, item), Q_ARG(int, row)) || !item) {
                    return 5;
                }
                const auto appValue = item->property("app");
                const auto appEntry = appValue.canConvert<QJSValue>() ? appValue.value<QJSValue>().toVariant().toMap() : appValue.toMap();
                if (appEntry.value("id") != entry.value("id")) {
                    std::cerr << "Repeater order does not match model\n";
                    return 8;
                }
                const auto x = item->property("x").toDouble();
                const auto y = item->property("y").toDouble();
                if (previousX >= 0 && (x > previousX || (x == previousX && y <= previousY))) {
                    std::cerr << "Visual order differs from " << key << " model order in " << mode << '\n';
                    return 6;
                }
                const auto position = entry.value("position").toMap();
                if (position.value("x").toDouble() != x || position.value("y").toDouble() != y) {
                    return 7;
                }
                previousX = x;
                previousY = y;
            }
        }
    }
    model.setOrganization("stack");
    for (const auto& key : {"name", "type", "date", "size"}) {
        QVariantList expanded;
        for (const auto& group : model.groups()) {
            expanded.append(group.toMap().value("key"));
        }
        controller->setProperty("expandedDesktopStacks", expanded);
        if (!QMetaObject::invokeMethod(controller, "wallpaperAction", Q_ARG(QVariant, QVariant(key)))) {
            return 9;
        }
        timer.restart();
        while (timer.elapsed() < 100) {
            app.processEvents();
            QThread::msleep(5);
        }

        QHash<QString, int> stackSlots;
        int slot = 0;
        for (const auto& group : model.groups()) {
            for (const auto& id : group.toMap().value("members").toStringList()) {
                stackSlots.insert(id, slot++);
            }
        }
        for (int row = 0; row < model.rowCount(); ++row) {
            const auto entry = model.data(model.index(row), Qt::UserRole + 1).toMap();
            QQuickItem* item = nullptr;
            auto* repeater = root->findChild<QObject*>("repeater");
            if (!QMetaObject::invokeMethod(repeater, "itemAt", Q_RETURN_ARG(QQuickItem*, item), Q_ARG(int, row)) || !item) {
                return 10;
            }
            QVariant expected;
            const auto index = stackSlots.value(entry.value("id").toString());
            if (!QMetaObject::invokeMethod(controller, "desktopStackPosition", Q_RETURN_ARG(QVariant, expected), Q_ARG(QVariant, QVariant(index)))) {
                return 11;
            }
            const auto position = expected.toPointF();
            if (item->x() != position.x() || item->y() != position.y()) {
                std::cerr << "Expanded stack does not follow sorted groups\n";
                return 12;
            }
        }
    }
    delete root;
    std::cout << "Qt/QML desktop: all four menu actions order and persist real repeater items in Free/Grid/Stack\n";
}
