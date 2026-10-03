#include <pedro/papi/io/transfer/manager.hpp>

#include <QFileInfo>
#include <QFutureWatcher>
#include <QtConcurrentRun>

#include <filesystem>

namespace Pedro::Papi::Io::Transfer {

    Manager::Manager(QObject* parent) : QObject(parent) {
    }

    bool Manager::busy() const {
        return transferring;
    }

    bool Manager::canMove(const QVariantList& values, const QUrl& requestedDestination) const {
        namespace fs = std::filesystem;
        const auto destination = requestedDestination.scheme().isEmpty() ? QUrl::fromLocalFile(requestedDestination.toString()) : requestedDestination;
        if (transferring || values.isEmpty() || !destination.isLocalFile() || !QFileInfo(destination.toLocalFile()).isDir()) {
            return false;
        }
        try {
            const auto folder = fs::weakly_canonical(fs::path(destination.toLocalFile().toStdString()));
            for (const auto& value : values) {
                const auto url = value.toUrl();
                if (!url.isLocalFile() || !QFileInfo::exists(url.toLocalFile())) {
                    return false;
                }
                const auto source = fs::weakly_canonical(fs::path(url.toLocalFile().toStdString()));
                const auto relative = folder.lexically_relative(source);
                if (source.parent_path() == folder || (fs::is_directory(source) && (relative.empty() || *relative.begin() != ".."))) {
                    return false;
                }
            }
        } catch (const fs::filesystem_error&) {
            return false;
        }
        return true;
    }

    void Manager::move(const QVariantList& urls, const QUrl& destination) {
        if (canMove(urls, destination)) {
            transfer(urls, destination, true);
        }
    }

    void Manager::transfer(const QVariantList& values, const QUrl& requestedDestination, bool cut) {
        const auto destination = requestedDestination.scheme().isEmpty() ? QUrl::fromLocalFile(requestedDestination.toString()) : requestedDestination;
        if (transferring || values.isEmpty() || !destination.isLocalFile() || !QFileInfo(destination.toLocalFile()).isDir()) {
            return;
        }
        QList<QUrl> urls;
        for (const auto& value : values) {
            const auto url = value.toUrl();
            if (!url.isLocalFile() || !QFileInfo::exists(url.toLocalFile())) {
                return;
            }
            if (!urls.contains(url)) {
                urls.append(url);
            }
        }
        transferring = true;
        emit changed();
        auto* watcher = new QFutureWatcher<QString>(this);
        connect(watcher, &QFutureWatcher<QString>::finished, this, [this, watcher] {
            const auto error = watcher->result();
            watcher->deleteLater();
            transferring = false;
            emit changed();
            if (!error.isEmpty()) {
                emit failed(error);
            }
            emit finished(error);
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
                    if (cut) {
                        std::error_code error;
                        fs::rename(source, target, error);
                        if (!error) {
                            continue;
                        }
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
