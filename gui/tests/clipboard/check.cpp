#include <pedro/papi/gui/clipboard/manager.hpp>

#include <QClipboard>
#include <QDir>
#include <QElapsedTimer>
#include <QFile>
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
    manager.paste(QUrl::fromLocalFile(root + "/destination"));
    require(!manager.canPaste(), "Concurrent paste must be disabled");
    wait();
    require(error.isEmpty() && QFile::exists(root + "/destination/folder/note.txt"), "Folder contents must be copied");
    manager.paste(QUrl::fromLocalFile(root + "/destination"));
    wait();
    require(QFile::exists(root + "/destination/folder (2)/note.txt"), "Collision must preserve both folders");
    manager.paste(folder);
    wait();
    require(!error.isEmpty(), "Recursive folder paste must fail");
    error.clear();
    manager.copy({QUrl::fromLocalFile(file.fileName())}, true);
    manager.paste(QUrl::fromLocalFile(root + "/destination"));
    wait();
    require(error.isEmpty() && !QFile::exists(file.fileName()) && QFile::exists(root + "/destination/note.txt"), "Cut paste must move the file");
    require(!manager.canPaste(), "Successful cut must clear the clipboard");
    auto* mime = new QMimeData;
    mime->setUrls({QUrl("https://example.com/file")});
    QGuiApplication::clipboard()->setMimeData(mime);
    require(!manager.canPaste(), "Web links must not enable file paste");
    std::cout << "Clipboard: copy, cut, collision, recursive protection and availability passed\n";
}
