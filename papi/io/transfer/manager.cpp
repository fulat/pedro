#include <gio/gio.h>

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
            if ((!url.isLocalFile() || !QFileInfo::exists(url.toLocalFile())) && (cut || url.scheme() != "trash")) {
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
                    fs::path source(url.toLocalFile().toStdString());
                    fs::path name = source.filename();
                    if (url.scheme() == "trash") {
                        auto* file = g_file_new_for_uri(url.toEncoded().constData());
                        GError* error = nullptr;
                        auto* info = g_file_query_info(file, "standard::target-uri,trash::orig-path", G_FILE_QUERY_INFO_NOFOLLOW_SYMLINKS, nullptr, &error);
                        g_object_unref(file);
                        if (!info) {
                            const auto message = error ? QString::fromUtf8(error->message) : QStringLiteral("Cannot read trashed file");
                            g_clear_error(&error);
                            return message;
                        }
                        const auto* address = g_file_info_get_attribute_string(info, G_FILE_ATTRIBUTE_STANDARD_TARGET_URI);
                        const QUrl targetUrl(address ? QString::fromUtf8(address) : QString{});
                        const auto* original = g_file_info_get_attribute_byte_string(info, G_FILE_ATTRIBUTE_TRASH_ORIG_PATH);
                        if (!targetUrl.isLocalFile()) {
                            g_object_unref(info);
                            return QStringLiteral("The trashed file has no local copy location");
                        }
                        source = fs::path(targetUrl.toLocalFile().toStdString());
                        name = original ? fs::path(original).filename() : source.filename();
                        g_object_unref(info);
                    }
                    auto target = folder / name;
                    // Never overwrite existing files or recurse into the source folder.
                    const auto canonicalSource = fs::weakly_canonical(source);
                    const auto canonicalFolder = fs::weakly_canonical(folder);
                    auto relative = canonicalFolder.lexically_relative(canonicalSource);
                    if (fs::is_directory(source) && (relative.empty() || *relative.begin() != "..")) {
                        return QStringLiteral("Cannot paste a folder inside itself");
                    }
                    int suffix = 2;
                    while (fs::exists(target) || fs::is_symlink(target)) {
                        target = folder / (name.stem().string() + " (" + std::to_string(suffix++) + ")" + name.extension().string());
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
