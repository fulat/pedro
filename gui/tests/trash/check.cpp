#include <gio/gio.h>

#include <pedro/papi/io/trash/manager.h>
#include <pedro/papi/io/transfer/manager.hpp>
#include <pedro/papi/io/directory/model.hpp>

#include <QCoreApplication>
#include <QElapsedTimer>
#include <QFile>
#include <QFileInfo>
#include <QDir>
#include <QThread>
#include <QUrl>

#include <cstdlib>
#include <iostream>

void require(bool condition, const char* message) {
    if (!condition) {
        std::cerr << message << '\n';
        std::exit(1);
    }
}

QVariantList items() {
    QVariantList urls;
    auto* root = g_file_new_for_uri("trash:///");
    GError* error = nullptr;
    auto* enumerator = g_file_enumerate_children(root, "standard::name", G_FILE_QUERY_INFO_NOFOLLOW_SYMLINKS, nullptr, &error);
    require(enumerator != nullptr, error ? error->message : "No Trash provider");
    while (auto* info = g_file_enumerator_next_file(enumerator, nullptr, &error)) {
        auto* file = g_file_get_child(root, g_file_info_get_name(info));
        auto* uri = g_file_get_uri(file);
        urls.append(QUrl(QString::fromUtf8(uri)));
        g_free(uri);
        g_object_unref(file);
        g_object_unref(info);
    }
    require(error == nullptr, "Enumeration failed");
    g_object_unref(enumerator);
    g_object_unref(root);
    return urls;
}

void wait(Pedro::Papi::Io::Trash::Manager& manager, bool success = true) {
    QElapsedTimer timer;
    timer.start();
    while (manager.busy() && timer.elapsed() < 10000) {
        QCoreApplication::processEvents();
        while (g_main_context_iteration(nullptr, false)) {
        }
        QThread::msleep(5);
    }
    require(!manager.busy(), "Operation timed out");
    require(success == manager.error().isEmpty(), qPrintable(manager.error()));
}

void waitItems(int count) {
    QElapsedTimer timer;
    timer.start();
    while (items().size() != count && timer.elapsed() < 5000) {
        QCoreApplication::processEvents();
        while (g_main_context_iteration(nullptr, false)) {
        }
        QThread::msleep(20);
    }
}

void write(const QString& path) {
    QFile file(path);
    require(file.open(QIODevice::WriteOnly), "Cannot create fixture");
    file.write("original");
}

int main(int argc, char** argv) {
    QCoreApplication app(argc, argv);
    require(qEnvironmentVariable("PEDRO_TRASH_TEST_SANDBOX") == "1", "Requires isolated sandbox");
    require(items().isEmpty(), "Test Trash must start empty");
    Pedro::Papi::Io::Trash::Manager manager;
    const QString base = QDir::homePath() + "/input";
    QDir().mkpath(base + "/nested");
    const auto path = base + "/.hidden fotografía #%25.txt";
    write(path);
    write(base + "/nested/child.txt");
    // GVfs polling on shared VM filesystems observes directory timestamps in seconds.
    QThread::msleep(1100);
    manager.move({QUrl::fromLocalFile(path), QUrl::fromLocalFile(base + "/nested")});
    wait(manager);
    waitItems(2);
    Pedro::Papi::Io::Directory::Model directory;
    directory.openPlace("trash");
    QElapsedTimer listingTimer;
    listingTimer.start();
    while ((directory.loading() || directory.rowCount() != 2) && listingTimer.elapsed() < 5000) {
        QCoreApplication::processEvents();
        while (g_main_context_iteration(nullptr, false)) {
        }
        QThread::msleep(20);
    }
    require(directory.error().isEmpty() && directory.rowCount() == 2, "Trash directory must include hidden files");
    for (const auto& value : directory.files() + directory.folders()) {
        const auto entry = value.toMap();
        require(entry.value("inTrash").toBool() && entry.value("canRestore").toBool() && !entry.value("originalPath").toString().isEmpty(), "Missing restoration metadata");
    }
    require(!QFile::exists(path) && items().size() == 2, "Trash failed");
    QDir().mkpath(base + "/copies");
    Pedro::Papi::Io::Transfer::Manager transfer;
    QString transferError;
    QObject::connect(&transfer, &Pedro::Papi::Io::Transfer::Manager::finished, [&](const QString& error) { transferError = error; });
    transfer.transfer(items(), QUrl::fromLocalFile(base + "/copies"), false);
    QElapsedTimer copyTimer;
    copyTimer.start();
    while (transfer.busy() && copyTimer.elapsed() < 5000) {
        QCoreApplication::processEvents();
        QThread::msleep(10);
    }
    require(!transfer.busy() && transferError.isEmpty() && QFile::exists(base + "/copies/" + QFileInfo(path).fileName()) && QFile::exists(base + "/copies/nested/child.txt") && items().size() == 2, "Copy from Trash must preserve source and original names");
    write(path);
    manager.restore(items());
    wait(manager, false);
    waitItems(1);
    require(items().size() == 1 && QFile::exists(base + "/nested/child.txt"), "Restore conflict must preserve item");
    QFile::remove(path);
    manager.restore(items());
    wait(manager);
    waitItems(0);
    require(QFile::exists(path) && items().isEmpty(), "Restore failed");
    manager.remove({QUrl::fromLocalFile(path), QUrl("trash:///")});
    wait(manager, false);
    require(QFile::exists(path), "Unsafe removal accepted");
    QFile::link(path, base + "/link");
    QThread::msleep(1100);
    manager.move({QUrl::fromLocalFile(base + "/nested"), QUrl::fromLocalFile(base + "/link")});
    wait(manager);
    manager.empty();
    wait(manager);
    waitItems(0);
    require(items().isEmpty() && QFile::exists(path), "Empty failed or followed symlink");
    const auto partialPath = base + "/partial.txt";
    write(partialPath);
    QThread::msleep(1100);
    manager.move({QUrl::fromLocalFile(partialPath), QUrl::fromLocalFile(base + "/missing")});
    wait(manager, false);
    waitItems(1);
    require(items().size() == 1, "Partial batch failed");
    QDir(base).removeRecursively();
    manager.restore(items());
    wait(manager);
    require(QFile::exists(partialPath), "Restore must recreate original parent");
    QDir().mkpath(base + "/moved");
    QThread::msleep(1100);
    manager.move({QUrl::fromLocalFile(partialPath)});
    wait(manager);
    waitItems(1);
    write(base + "/moved/partial.txt");
    manager.relocate(items(), QUrl::fromLocalFile(base + "/moved"));
    wait(manager, false);
    require(items().size() == 1, "Move conflict must preserve Trash item");
    QFile::remove(base + "/moved/partial.txt");
    manager.relocate(items(), QUrl::fromLocalFile(base + "/moved"));
    wait(manager);
    waitItems(0);
    require(items().isEmpty() && QFile::exists(base + "/moved/partial.txt"), "Move out of Trash must clean metadata");
    std::cout << "PASS: trash, nested folders, hidden/Unicode names, restore/conflicts, protected removal, empty, symlinks, partial batches and missing parents\n";
}
