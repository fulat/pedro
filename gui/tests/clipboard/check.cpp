#include <pedro/papi/gui/clipboard/manager.hpp>

#include <QClipboard>
#include <QDir>
#include <QElapsedTimer>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QMimeData>
#include <QThread>

#include <iostream>

void require(bool condition, const char* message) {
    if (!condition) {
        std::cerr << message << '\n';
        std::exit(1);
    }
}

int main(int argc, char** argv) {
    QGuiApplication app(argc, argv);
    Pedro::Papi::Gui::Clipboard::Manager manager;
    QGuiApplication::clipboard()->setText("ordinary text");
    require(!manager.canPaste(), "Text clipboard must leave paste disabled");
    const QString root = QString::fromLocal8Bit(argv[1]);
    QDir(root).removeRecursively();
    QDir().mkpath(root + "/source/folder");
    QDir().mkpath(root + "/destination");
    QFile file(root + "/source/folder/note.txt");
    require(file.open(QIODevice::WriteOnly), "Cannot write fixture");
    file.write("hello");
    file.close();
    QString error;
    QObject::connect(&manager, &Pedro::Papi::Gui::Clipboard::Manager::failed, [&](const auto& message) { error = message; });
    auto wait = [&] {
        QElapsedTimer timer;
        timer.start();
        while (manager.busy() && timer.elapsed() < 5000) {
            app.processEvents();
            QThread::msleep(5);
        }
        require(!manager.busy(), "Clipboard operation timed out");
    };
    const auto folder = QUrl::fromLocalFile(root + "/source/folder");
    manager.copy({folder});
    require(manager.canPaste(), "Copied files must enable paste");
    require(manager.cutFiles().isEmpty() && !manager.isCut(folder), "Copy must not mark an item as cut");
    manager.paste(QUrl::fromLocalFile(root + "/destination"));
    require(!manager.canPaste(), "Concurrent paste must be disabled");
    wait();
    require(error.isEmpty() && QFile::exists(root + "/destination/folder/note.txt"), qPrintable(QStringLiteral("Folder contents must be copied: ") + error));
    manager.paste(QUrl::fromLocalFile(root + "/destination"));
    wait();
    require(QFile::exists(root + "/destination/folder (2)/note.txt"), "Collision must preserve both folders");
    manager.paste(folder);
    wait();
    require(!error.isEmpty(), "Recursive folder paste must fail");
    error.clear();
    manager.copy({QUrl::fromLocalFile(file.fileName())}, true);
    require(manager.isCut(QUrl::fromLocalFile(file.fileName())) && manager.cutFiles().size() == 1 && !manager.isCut(folder), "Cut state must identify only clipboard sources");
    manager.paste(QUrl::fromLocalFile(root + "/destination"));
    wait();
    require(error.isEmpty() && !QFile::exists(file.fileName()) && QFile::exists(root + "/destination/note.txt"), "Cut paste must move the file");
    require(!manager.canPaste(), "Successful cut must clear the clipboard");
    require(manager.cutFiles().isEmpty(), "Successful cut must clear visual state");
    auto* mime = new QMimeData;
    mime->setUrls({QUrl("https://example.com/file")});
    QGuiApplication::clipboard()->setMimeData(mime);
    require(!manager.canPaste(), "Web links must not enable file paste");
    manager.copy({QUrl("trash:///pedro-test.txt")});
    require(manager.canPaste() && QGuiApplication::clipboard()->mimeData()->urls().first().scheme() == "trash", "Trash copy must preserve the GIO URI");
    auto* trashCut = new QMimeData;
    trashCut->setData("x-special/gnome-copied-files", "cut\ntrash:///pedro-test.txt");
    QGuiApplication::clipboard()->setMimeData(trashCut);
    require(!manager.canPaste(), "Cut from Trash must use the metadata-aware move operation");
    Pedro::Papi::Io::Transfer::Manager transfer;
    const QVariantList moving{QUrl::fromLocalFile(root + "/destination/note.txt")};
    const auto destination = QUrl::fromLocalFile(root + "/destination/folder");
    require(!transfer.canMove({folder}, folder), "A folder cannot be dropped inside itself");
    require(!transfer.canMove(moving, QUrl::fromLocalFile(root + "/destination")), "Dropping into the same parent must be rejected");
    require(transfer.canMove(moving, destination), "Files can be dropped into a different folder");
    QGuiApplication::clipboard()->setText("keep this clipboard");
    transfer.move(moving, destination);
    QElapsedTimer timer;
    timer.start();
    while (transfer.busy() && timer.elapsed() < 5000) {
        app.processEvents();
        QThread::msleep(5);
    }
    require(!transfer.busy() && !QFile::exists(root + "/destination/note.txt") && QFile::exists(root + "/destination/folder/note (2).txt"), "File drop must move without overwriting");
    require(QGuiApplication::clipboard()->text() == "keep this clipboard", "Dragging must preserve clipboard contents");
    require(!transfer.canMove({folder}, QUrl::fromLocalFile(root + "/source/folder/nested")), "Nested folder destinations must be rejected");
    transfer.move({folder}, QUrl::fromLocalFile(root + "/destination"));
    timer.restart();
    while (transfer.busy() && timer.elapsed() < 5000) {
        app.processEvents();
        QThread::msleep(5);
    }
    require(!transfer.busy() && !QFile::exists(root + "/source/folder") && QDir(root + "/destination/folder (3)").exists(), "Folder drop must move the directory and preserve collisions");
    QFile externalFile(root + "/source/external.txt");
    require(externalFile.open(QIODevice::WriteOnly), "Cannot create external clipboard fixture");
    externalFile.write("GNOME clipboard fixture");
    externalFile.close();
    auto* external = new QMimeData;
    external->setData("x-special/gnome-copied-files", "copy\n" + QUrl::fromLocalFile(externalFile.fileName()).toEncoded());
    QGuiApplication::clipboard()->setMimeData(external);
    require(manager.canPaste(), "GNOME file clipboard must be accepted");
    manager.paste(QUrl::fromLocalFile(root + "/destination"));
    wait();
    require(QFile::exists(root + "/destination/external.txt"), "External GNOME clipboard paste failed");
    const auto valid = QUrl::fromLocalFile(root + "/destination/external.txt");
    const auto missing = QUrl::fromLocalFile(root + "/source/missing.txt");
    manager.copy({valid, missing}, true);
    manager.paste(QUrl::fromLocalFile(root + "/source"));
    wait();
    require(!manager.operation()->error().isEmpty() && manager.operation()->completed().contains(QVariant(valid)), "Partial batch must report successes and failures");
    require(QGuiApplication::clipboard()->mimeData()->urls() == QList<QUrl>{missing}, "Partial cut must retain only failed sources");
    require(manager.isCut(missing) && !manager.isCut(valid), "Partial cuts must update visual state");
    QFile large(root + "/source/large.bin");
    require(large.open(QIODevice::WriteOnly) && large.resize(64 * 1024 * 1024), "Cannot create cancellation fixture");
    large.close();
    const auto largeUrl = QUrl::fromLocalFile(large.fileName());
    manager.copy({largeUrl}, true);
    manager.paste(QUrl::fromLocalFile(root + "/destination"));
    manager.operation()->cancel();
    wait();
    require(manager.operation()->cancelled() && QFile::exists(large.fileName()) && manager.canPaste(), "Canceled cut must retain its source and clipboard");
    require(manager.isCut(largeUrl), "Cancellation must keep pending cut state");
    auto* externalCut = new QMimeData;
    externalCut->setData("x-special/gnome-copied-files", "cut\n" + largeUrl.toEncoded());
    QGuiApplication::clipboard()->setMimeData(externalCut);
    require(manager.isCut(largeUrl), "External GNOME cuts must mark matching entries");
    manager.copy({largeUrl});
    require(manager.cutFiles().isEmpty(), "Replacing cut with copy must clear visual state");
    QGuiApplication::clipboard()->setText("replacement text");
    require(manager.cutFiles().isEmpty(), "Ordinary clipboard content must clear cut state");
    const auto permissions = QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ExeOwner;
    QDir().mkpath(root + "/source/private");
    require(QFile::setPermissions(root + "/source/private", permissions), "Cannot set directory permissions");
    manager.copy({QUrl::fromLocalFile(root + "/source/private")});
    manager.paste(QUrl::fromLocalFile(root + "/destination"));
    wait();
    const auto others = QFileDevice::ReadOther | QFileDevice::WriteOther | QFileDevice::ExeOther;
    require(!(QFile::permissions(root + "/destination/private") & others), "Copy must preserve private directory permissions");
    require(QFile::link(root + "/source/absent", root + "/source/dangling"), "Cannot create dangling link");
    manager.copy({QUrl::fromLocalFile(root + "/source/dangling")});
    require(manager.canPaste(), "Dangling symlinks are valid file clipboard entries");
    manager.paste(QUrl::fromLocalFile(root + "/destination"));
    wait();
    require(QFileInfo(root + "/destination/dangling").isSymLink(), "Copy must preserve symlinks without following their targets");
    auto* malformed = new QMimeData;
    malformed->setData("x-special/gnome-copied-files", "invalid\n" + largeUrl.toEncoded());
    QGuiApplication::clipboard()->setMimeData(malformed);
    require(!manager.canPaste(), "Malformed GNOME clipboard must not enable paste");
    std::cout << "Clipboard: copy, cut, collision, recursive protection and availability passed\n";
}
