#include <pedro/papi/gui/clipboard/manager.hpp>

#include <QClipboard>
#include <QGuiApplication>
#include <QMimeData>
#include <QFileInfo>
#include <QFutureWatcher>
#include <QtConcurrentRun>

#include <algorithm>
#include <filesystem>

namespace Pedro::Papi::Gui::Clipboard {

    namespace {

        QList<QUrl> files() {
            const auto* mime = QGuiApplication::clipboard()->mimeData();
            if (!mime) {
                return {};
            }
            if (mime->hasFormat("x-special/gnome-copied-files")) {
                QList<QUrl> urls;
                const auto lines = mime->data("x-special/gnome-copied-files").split('\n');
                for (int index = 1; index < lines.size(); ++index) {
                    const QUrl url(QString::fromUtf8(lines.at(index)));
                    if (url.isValid() && !url.isEmpty()) {
                        urls.append(url);
                    }
                }
                return urls;
            }
            return mime->urls();
        }

    }

    Manager::Manager(QObject* parent) : QObject(parent) {
        connect(QGuiApplication::clipboard(), &QClipboard::dataChanged, this, &Manager::changed);
    }

    bool Manager::canPaste() const {
        const auto urls = files();
        return !transferring && !urls.isEmpty() && std::all_of(urls.cbegin(), urls.cend(), [](const auto& url) { return url.isLocalFile() && QFileInfo::exists(url.toLocalFile()); });
    }

    bool Manager::busy() const {
        return transferring;
    }

    void Manager::copy(const QVariantList& values, bool cut) {
        QList<QUrl> urls;
        QByteArray data = cut ? "cut" : "copy";
        for (const auto& value : values) {
            const auto url = value.toUrl();
            if (url.isLocalFile()) {
                urls.append(url);
                data += '\n' + url.toEncoded();
            }
        }
        if (urls.isEmpty()) {
            return;
        }
        auto* mime = new QMimeData;
        mime->setUrls(urls);
        mime->setData("x-special/gnome-copied-files", data);
        QGuiApplication::clipboard()->setMimeData(mime);
    }

    void Manager::paste(const QUrl& requestedDestination) {
        const auto destination = requestedDestination.scheme().isEmpty() ? QUrl::fromLocalFile(requestedDestination.toString()) : requestedDestination;
        if (!canPaste() || !destination.isLocalFile() || !QFileInfo(destination.toLocalFile()).isDir()) {
            return;
        }
        const auto urls = files();
        const auto* mime = QGuiApplication::clipboard()->mimeData();
        const auto original = mime->data("x-special/gnome-copied-files");
        const bool cut = original.startsWith("cut\n");
        transferring = true;
        emit changed();
        auto* watcher = new QFutureWatcher<QString>(this);
        connect(watcher, &QFutureWatcher<QString>::finished, this, [this, watcher, cut, original, urls] {
            const auto error = watcher->result();
            watcher->deleteLater();
            transferring = false;
            if (!error.isEmpty()) {
                emit failed(error);
            } else if (cut && files() == urls && QGuiApplication::clipboard()->mimeData()->data("x-special/gnome-copied-files") == original) {
                QGuiApplication::clipboard()->clear();
            }
            emit changed();
        });
        watcher->setFuture(QtConcurrent::run([urls, destination, cut] {
            namespace fs = std::filesystem;
            try {
                const fs::path folder(destination.toLocalFile().toStdString());
                for (const auto& url : urls) {
                    const fs::path source(url.toLocalFile().toStdString());
                    auto target = folder / source.filename();
                    // Never overwrite existing files or recurse into the source folder.
                    const auto canonicalSource = fs::weakly_canonical(source);
                    const auto canonicalFolder = fs::weakly_canonical(folder);
                    auto relative = canonicalFolder.lexically_relative(canonicalSource);
                    if (fs::is_directory(source) && (relative.empty() || *relative.begin() != "..")) {
                        return QStringLiteral("Cannot paste a folder inside itself");
                    }
                    int suffix = 2;
                    while (fs::exists(target) || fs::is_symlink(target)) {
                        target = folder / (source.stem().string() + " (" + std::to_string(suffix++) + ")" + source.extension().string());
                    }
                    fs::copy(source, target, fs::copy_options::recursive | fs::copy_options::copy_symlinks);
                    if (cut) {
                        fs::remove_all(source);
                    }
                }
            } catch (const fs::filesystem_error& error) {
                return QString::fromUtf8(error.what());
            }
            return QString();
        }));
    }

}
