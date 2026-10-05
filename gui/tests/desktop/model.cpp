#include <pedro/papi/io/desktop/model.hpp>

#include <QAbstractItemModelTester>
#include <QCollator>
#include <QCoreApplication>
#include <QElapsedTimer>
#include <QFile>
#include <QLocale>
#include <QPersistentModelIndex>
#include <QSignalSpy>
#include <QThread>

#include <cstdlib>
#include <functional>
#include <iostream>

namespace {

    void require(bool condition, const char* message) {
        if (!condition) {
            std::cerr << message << '\n';
            std::exit(1);
        }
    }

    void waitFor(const std::function<bool()>& ready) {
        QElapsedTimer timer;
        timer.start();

        while (!ready() && timer.elapsed() < 5000) {
            QCoreApplication::processEvents();
            QThread::msleep(5);
        }

        require(ready(), "Timed out waiting for desktop filesystem events");
    }

    QVariantMap entryAt(const Pedro::Papi::Io::Desktop::Model& model, int row) {
        return model.data(model.index(row), Qt::UserRole + 1).toMap();
    }

}

int main(int argc, char** argv) {
    QCoreApplication app(argc, argv);
    QLocale::setDefault(QLocale(QLocale::English, QLocale::UnitedStates));
    using Pedro::Papi::Io::Desktop::Model;
    Model model;
    QAbstractItemModelTester tester(&model, QAbstractItemModelTester::FailureReportingMode::Fatal);
    QSignalSpy resets(&model, &Model::modelReset);
    QSignalSpy requested(&model, &Model::sortRequested);
    waitFor([&] { return !model.loading(); });
    require(model.error().isEmpty() && model.rowCount() == 5, "Fixture should contain five entries");

    QCollator collator;
    collator.setNumericMode(true);
    collator.setCaseSensitivity(Qt::CaseInsensitive);
    model.sort("name");
    require(entryAt(model, 0).value("name") == "Alpha.txt", "Name sort should be alphabetic");
    require(entryAt(model, 3).value("name") == "node2.txt" && entryAt(model, 4).value("name") == "node10.txt", "Name sort should use natural numbers");

    const QPersistentModelIndex tracked(model.index(4));
    const auto trackedId = entryAt(model, 4).value("id");
    for (const auto& mode : {"grid", "free", "stack"}) {
        model.setOrganization(mode);
        for (const auto& key : {"name", "type", "date", "size"}) {
            if (model.sortKey() == key) {
                model.sort(key);
            }
            model.sort(key);
            require(model.organization() == mode, "Sorting must not change organization");
            require(model.sortKey() == key, "Sort key should reflect the selected criterion");
            require(tracked.data(Qt::UserRole + 1).toMap().value("id") == trackedId, "Sorting must preserve persistent model identity");
            for (int row = 1; row < model.rowCount(); ++row) {
                const auto previous = entryAt(model, row - 1);
                const auto current = entryAt(model, row);
                if (QString(key) == "date" || QString(key) == "size") {
                    const auto attribute = QString(key) == "date" ? "modified" : "size";
                    require(previous.value(attribute).toULongLong() >= current.value(attribute).toULongLong(), "Numeric sort should be descending");
                } else if (QString(key) == "type") {
                    const bool previousFolder = previous.value("isDirectory").toBool();
                    const bool currentFolder = current.value("isDirectory").toBool();
                    require(previousFolder || !currentFolder, "Type sort should place directories first");
                    if (previousFolder == currentFolder) {
                        require(collator.compare(previous.value("type").toString(), current.value("type").toString()) <= 0, "Type sort should compare content types");
                    }
                } else {
                    require(collator.compare(previous.value("name").toString(), current.value("name").toString()) <= 0, "Name order should be consistent");
                }
            }
        }
    }

    const auto beforeRepeat = requested.size();
    model.sort("size");
    require(model.sortKey().isEmpty() && requested.size() == beforeRepeat, "Repeating sort should disable sorting without redistribution");
    model.sort("invalid");
    require(model.sortKey().isEmpty() && requested.size() == beforeRepeat, "Unknown sort criterion should be ignored");

    model.setOrganization("free");
    const auto id = entryAt(model, 0).value("id").toString();
    model.savePosition(id, 123, 234);
    model.sort("name");
    bool positionPreserved = false;
    for (int row = 0; row < model.rowCount(); ++row) {
        const auto entry = entryAt(model, row);
        if (entry.value("id") == id) {
            const auto position = entry.value("position").toMap();
            positionPreserved = position.value("x") == 123 && position.value("y") == 234;
        }
    }
    require(positionPreserved, "Model sort must leave coordinate persistence to the GUI");

    model.sort("size");
    model.savePosition(id, 500, 600);
    model.sort("size");
    bool restoredPosition = false;
    for (int row = 0; row < model.rowCount(); ++row) {
        const auto entry = entryAt(model, row);
        if (entry.value("id") == id) {
            const auto position = entry.value("position").toMap();
            restoredPosition = position.value("x") == 123 && position.value("y") == 234;
        }
    }
    require(restoredPosition, "Disabling sort should restore the original manual position across criterion changes");
    model.sort("size");
    model.savePosition(id, 450, 350, true);
    model.sort("type");
    model.sort("type");
    for (int row = 0; row < model.rowCount(); ++row) {
        const auto entry = entryAt(model, row);
        if (entry.value("id") == id) {
            const auto position = entry.value("position").toMap();
            require(position.value("x") == 450 && position.value("y") == 350, "Manual move during sorting must become the restored position");
        }
    }
    model.sort("size");
    QFile added(model.directory() + "/new.txt");
    require(added.open(QIODevice::WriteOnly), "Cannot create monitored file");
    added.write(QByteArray(10000, 'x'));
    added.close();
    waitFor([&] { return model.rowCount() == 6; });
    require(entryAt(model, 0).value("name") == "new.txt", "New entries should respect active sort");
    require(resets.isEmpty(), "Sorting and filesystem updates must not reset the model");
    QFile::remove(added.fileName());
    waitFor([&] { return model.rowCount() == 5; });

    const QPersistentModelIndex renamedIndex(model.index(0));
    const auto original = entryAt(model, 0);
    model.sort("size");
    model.savePosition(original.value("id").toString(), 215, 325);
    QSignalSpy removed(&model, &Model::rowsRemoved);
    QSignalSpy inserted(&model, &Model::rowsInserted);
    const auto originalPath = original.value("path").toString();
    const auto renamedPath = originalPath + ".renamed";
    require(QFile::rename(originalPath, renamedPath), "Cannot rename monitored file");
    waitFor([&] { return renamedIndex.isValid() && renamedIndex.data(Qt::UserRole + 1).toMap().value("path") == renamedPath && renamedIndex.data(Qt::UserRole + 1).toMap().value("name").toString().endsWith(".renamed"); });
    const auto renamedPosition = renamedIndex.data(Qt::UserRole + 1).toMap().value("position").toMap();
    require(removed.isEmpty() && inserted.isEmpty(), "Rename must retain the desktop row and delegate");
    require(renamedPosition.value("x") == 215 && renamedPosition.value("y") == 325, "Rename must retain its desktop position");
    require(QFile::rename(renamedPath, originalPath), "Cannot restore renamed fixture");
    waitFor([&] { return renamedIndex.data(Qt::UserRole + 1).toMap().value("path") == originalPath; });

    Model restored;
    waitFor([&] { return !restored.loading(); });
    require(restored.sortKey().isEmpty(), "New sessions must start without a selected sort");

    std::cout << "Desktop sort: all criteria, modes, persistence and filesystem events passed\n";
}
