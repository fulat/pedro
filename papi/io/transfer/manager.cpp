#include <gio/gio.h>

#include <pedro/papi/io/transfer/manager.hpp>

#include <QFileInfo>
#include <QDir>
#include <QFutureWatcher>
#include <QtConcurrentRun>

namespace Pedro::Papi::Io::Transfer {

    namespace {

        QString filePath(GFile* file) {
            auto* path = g_file_get_path(file);
            const auto result = path ? QString::fromLocal8Bit(path) : QString{};
            g_free(path);
            return result;
        }

        bool isSymlink(GFile* file, GCancellable* cancel) {
            auto* info = g_file_query_info(file, "standard::type", G_FILE_QUERY_INFO_NOFOLLOW_SYMLINKS, cancel, nullptr);
            const bool result = info && g_file_info_get_file_type(info) == G_FILE_TYPE_SYMBOLIC_LINK;
            g_clear_object(&info);
            return result;
        }

        struct Progress {
                Manager* manager;
                gint64 previous = -1;
        };

        void report(goffset done, goffset total, gpointer data) {
            auto* progress = static_cast<Progress*>(data);
            // Bound queued UI updates, even when GIO emits very frequent callbacks.
            const auto percent = total > 0 ? done * 100 / total : 0;
            if (percent == progress->previous) {
                return;
            }
            progress->previous = percent;
            QMetaObject::invokeMethod(progress->manager, "updateProgress", Qt::QueuedConnection, Q_ARG(double, total > 0 ? static_cast<double>(done) / total : 0));
        }

        void moved(GFile* source, GFile* destination, Manager* manager) {
            auto* from = g_file_get_uri(source);
            auto* to = g_file_get_uri(destination);
            const auto original = QUrl::fromEncoded(from);
            const auto target = QUrl::fromEncoded(to);
            g_free(from);
            g_free(to);
            QMetaObject::invokeMethod(manager, [manager, original, target] { emit manager->moved(original, target); }, Qt::QueuedConnection);
        }

        bool transferItem(GFile* source, GFile* target, bool cut, GCancellable* cancel, Progress* progress, GError** error) {
            auto* basename = g_file_get_basename(source);
            const auto name = QString::fromUtf8(basename);
            g_free(basename);
            QMetaObject::invokeMethod(progress->manager, [manager = progress->manager, name] { manager->setCurrentFile(name); }, Qt::QueuedConnection);
            progress->previous = -1;
            const auto flags = G_FILE_COPY_NOFOLLOW_SYMLINKS;
            if (cut && g_file_move(source, target, flags, cancel, report, progress, error)) {
                moved(source, target, progress->manager);
                return true;
            }
            if (cut) {
                if (!g_error_matches(*error, G_IO_ERROR, G_IO_ERROR_WOULD_RECURSE)) {
                    return false;
                }
                g_clear_error(error);
            }
            const auto type = g_file_query_file_type(source, G_FILE_QUERY_INFO_NOFOLLOW_SYMLINKS, cancel);
            if (type != G_FILE_TYPE_DIRECTORY) {
                return g_file_copy(source, target, flags, cancel, report, progress, error);
            }
            // GIO provides file transfer; its API requires directory orchestration.
            // Never follow links, overwrite a target, or delete uncopied contents.
            if (!g_file_make_directory(target, cancel, error)) {
                return false;
            }
            auto* children = g_file_enumerate_children(source, "standard::name", G_FILE_QUERY_INFO_NOFOLLOW_SYMLINKS, cancel, error);
            if (!children) {
                return false;
            }
            bool success = true;
            while (auto* info = g_file_enumerator_next_file(children, cancel, error)) {
                auto* child = g_file_enumerator_get_child(children, info);
                auto* destination = g_file_get_child(target, g_file_info_get_name(info));
                success = transferItem(child, destination, cut, cancel, progress, error);
                g_object_unref(destination);
                g_object_unref(child);
                g_object_unref(info);
                if (!success) {
                    break;
                }
            }
            g_object_unref(children);
            if (*error) {
                success = false;
            }
            if (success) {
                auto* permissions = g_file_query_info(source, "unix::mode", G_FILE_QUERY_INFO_NOFOLLOW_SYMLINKS, cancel, error);
                if (permissions && g_file_info_has_attribute(permissions, "unix::mode")) {
                    success = g_file_set_attribute_uint32(target, "unix::mode", g_file_info_get_attribute_uint32(permissions, "unix::mode"), G_FILE_QUERY_INFO_NONE, cancel, error);
                    if (!success && g_error_matches(*error, G_IO_ERROR, G_IO_ERROR_NOT_SUPPORTED)) {
                        g_clear_error(error);
                        success = true;
                    }
                }
                g_clear_object(&permissions);
                if (*error) {
                    success = false;
                }
            }
            if (success && cut) {
                success = g_file_delete(source, cancel, error);
                if (success) {
                    moved(source, target, progress->manager);
                }
            }
            return success;
        }

    }

    Manager::Manager(QObject* parent) : QObject(parent) {
    }

    Manager::~Manager() {
        cancel();
        for (auto* watcher : findChildren<QFutureWatcherBase*>()) {
            watcher->waitForFinished();
        }
    }

    bool Manager::busy() const {
        return transferring;
    }

    bool Manager::cancelled() const {
        return wasCancelled;
    }

    double Manager::progress() const {
        return fraction;
    }

    QString Manager::currentFile() const {
        return current;
    }

    QString Manager::error() const {
        return failure;
    }

    QVariantList Manager::completed() const {
        return successes;
    }

    void Manager::cancel() {
        if (cancellation) {
            g_cancellable_cancel(cancellation.get());
        }
    }

    void Manager::dismissError() {
        failure.clear();
        emit changed();
    }

    void Manager::setCurrentFile(const QString& name) {
        current = name;
        fraction = 0;
        emit changed();
    }

    void Manager::updateProgress(double value) {
        fraction = value;
        emit changed();
    }

    bool Manager::canMove(const QVariantList& values, const QUrl& requestedDestination) const {
        const auto destination = requestedDestination.scheme().isEmpty() ? QUrl::fromLocalFile(requestedDestination.toString()) : requestedDestination;
        if (transferring || values.isEmpty() || !destination.isLocalFile() || !QFileInfo(destination.toLocalFile()).isDir()) {
            return false;
        }
        const auto folder = QFileInfo(destination.toLocalFile()).canonicalFilePath();
        for (const auto& value : values) {
            const auto url = value.toUrl();
            const QFileInfo source(url.toLocalFile());
            if (!url.isLocalFile() || (!source.exists() && !source.isSymLink())) {
                return false;
            }
            const auto path = source.canonicalFilePath();
            if (source.dir().canonicalPath() == folder || (source.isDir() && !source.isSymLink() && (path == folder || folder.startsWith(path.endsWith('/') ? path : path + '/')))) {
                return false;
            }
        }
        return true;
    }

    void Manager::move(const QVariantList& urls, const QUrl& destination) {
        if (canMove(urls, destination)) {
            transfer(urls, destination, true);
        }
    }

    bool Manager::validName(const QString& name) const {
        return !name.trimmed().isEmpty() && name != "." && name != ".." && !name.contains('/') && !name.contains(QChar::Null);
    }

    void Manager::duplicate(const QUrl& url) {
        if (!url.isLocalFile() || QDir::cleanPath(url.toLocalFile()) == "/") {
            return;
        }
        transfer({url}, QUrl::fromLocalFile(QFileInfo(url.toLocalFile()).absolutePath()), false);
    }

    void Manager::rename(const QUrl& url, const QString& name) {
        if (transferring) {
            return;
        }
        if (!url.isLocalFile() || QDir::cleanPath(url.toLocalFile()) == "/" || !validName(name)) {
            failure = QStringLiteral("Invalid file name or location");
            emit changed();
            emit failed(failure);
            return;
        }
        cancellation = std::shared_ptr<GCancellable>(g_cancellable_new(), g_object_unref);
        fraction = 0;
        wasCancelled = false;
        failure.clear();
        successes.clear();
        current = QFileInfo(url.toLocalFile()).fileName();
        transferring = true;
        emit changed();
        using Result = QPair<QString, QUrl>;
        auto* watcher = new QFutureWatcher<Result>(this);
        connect(watcher, &QFutureWatcher<Result>::finished, this, [this, watcher, url] {
            const auto result = watcher->result();
            watcher->deleteLater();
            failure = result.first;
            wasCancelled = cancellation && g_cancellable_is_cancelled(cancellation.get());
            fraction = failure.isEmpty() ? 1 : 0;
            transferring = false;
            if (failure.isEmpty()) {
                successes.append(url);
                emit renamed(url, result.second);
            }
            emit changed();
            if (!failure.isEmpty() && !wasCancelled) {
                emit failed(failure);
            }
            emit finished(failure);
        });
        const auto cancel = cancellation;
        watcher->setFuture(QtConcurrent::run([url, name, cancel] {
            GError* error = nullptr;
            auto* source = g_file_new_for_uri(url.toEncoded().constData());
            auto* parent = g_file_get_parent(source);
            auto* info = g_file_query_info(source, "standard::type", G_FILE_QUERY_INFO_NOFOLLOW_SYMLINKS, cancel.get(), &error);
            auto* target = info && parent ? g_file_get_child_for_display_name(parent, name.toUtf8().constData(), &error) : nullptr;
            g_clear_object(&info);
            QUrl destination;
            QString failure;
            if (target && (g_file_equal(source, target) || g_file_move(source, target, G_FILE_COPY_NOFOLLOW_SYMLINKS, cancel.get(), nullptr, nullptr, &error))) {
                auto* uri = g_file_get_uri(target);
                destination = QUrl(QString::fromUtf8(uri));
                g_free(uri);
            } else {
                failure = error ? QString::fromUtf8(error->message) : QStringLiteral("The file cannot be renamed");
            }
            g_clear_error(&error);
            g_clear_object(&target);
            g_clear_object(&parent);
            g_object_unref(source);
            return Result{failure, destination};
        }));
    }

    void Manager::transfer(const QVariantList& values, const QUrl& requestedDestination, bool cut) {
        const auto destination = requestedDestination.scheme().isEmpty() ? QUrl::fromLocalFile(requestedDestination.toString()) : requestedDestination;
        if (transferring || values.isEmpty() || !destination.isLocalFile() || !QFileInfo(destination.toLocalFile()).isDir()) {
            return;
        }
        QList<QUrl> urls;
        for (const auto& value : values) {
            const auto url = value.toUrl();
            if (!url.isLocalFile() && (cut || url.scheme() != "trash")) {
                return;
            }
            if (!urls.contains(url)) {
                urls.append(url);
            }
        }
        cancellation = std::shared_ptr<GCancellable>(g_cancellable_new(), g_object_unref);
        fraction = 0;
        wasCancelled = false;
        failure.clear();
        successes.clear();
        transferring = true;
        emit changed();
        auto* watcher = new QFutureWatcher<QString>(this);
        connect(watcher, &QFutureWatcher<QString>::finished, this, [this, watcher] {
            const auto error = watcher->result();
            watcher->deleteLater();
            failure = error;
            wasCancelled = cancellation && g_cancellable_is_cancelled(cancellation.get());
            fraction = error.isEmpty() ? 1 : fraction;
            transferring = false;
            emit changed();
            if (!error.isEmpty() && !wasCancelled) {
                emit failed(error);
            }
            emit finished(error);
        });
        const auto cancel = cancellation;
        watcher->setFuture(QtConcurrent::run([this, urls, destination, cut, cancel] {
            QStringList errors;
            QVariantList completed;
            for (int index = 0; index < urls.size(); ++index) {
                if (g_cancellable_is_cancelled(cancel.get())) {
                    break;
                }
                auto* source = g_file_new_for_uri(urls.at(index).toEncoded().constData());
                auto* folder = g_file_new_for_uri(destination.toEncoded().constData());
                GError* error = nullptr;
                auto* info = g_file_query_info(source, "standard::name,standard::target-uri,trash::orig-path", G_FILE_QUERY_INFO_NOFOLLOW_SYMLINKS, cancel.get(), &error);
                QString name;
                if (info) {
                    name = QString::fromUtf8(g_file_info_get_name(info));
                    if (urls.at(index).scheme() == "trash") {
                        const auto* target = g_file_info_get_attribute_string(info, G_FILE_ATTRIBUTE_STANDARD_TARGET_URI);
                        const auto* original = g_file_info_get_attribute_byte_string(info, G_FILE_ATTRIBUTE_TRASH_ORIG_PATH);
                        name = original ? QFileInfo(QString::fromLocal8Bit(original)).fileName() : name;
                        if (target) {
                            g_object_unref(source);
                            source = g_file_new_for_uri(target);
                        } else {
                            g_set_error_literal(&error, G_IO_ERROR, G_IO_ERROR_NOT_FOUND, "The trashed file has no copy location");
                        }
                    }
                    g_object_unref(info);
                }
                auto* target = g_file_get_child(folder, name.toUtf8().constData());
                if (!error) {
                    // GIO compares actual paths; symlink aliases are also rejected.
                    const QFileInfo sourceInfo(filePath(source));
                    const auto sourcePath = sourceInfo.canonicalFilePath();
                    const auto folderPath = QFileInfo(destination.toLocalFile()).canonicalFilePath();
                    if (cut && sourceInfo.dir().canonicalPath() == folderPath) {
                        g_set_error_literal(&error, G_IO_ERROR, G_IO_ERROR_INVALID_ARGUMENT, "The source is already in the destination folder");
                    } else if (sourceInfo.isDir() && !sourceInfo.isSymLink() && (sourcePath == folderPath || folderPath.startsWith(sourcePath.endsWith('/') ? sourcePath : sourcePath + '/'))) {
                        g_set_error_literal(&error, G_IO_ERROR, G_IO_ERROR_INVALID_ARGUMENT, "Cannot paste a folder inside itself");
                    }
                }
                if (!error) {
                    int suffix = 2;
                    while (g_file_query_exists(target, cancel.get()) || isSymlink(target, cancel.get())) {
                        g_object_unref(target);
                        const QFileInfo item(name);
                        const auto extension = QFileInfo(filePath(source)).isDir() && !isSymlink(source, cancel.get()) ? QString{} : item.suffix();
                        const auto unique = (extension.isEmpty() ? name : item.completeBaseName()) + " (" + QString::number(suffix++) + ")" + (extension.isEmpty() ? QString{} : '.' + extension);
                        target = g_file_get_child(folder, unique.toUtf8().constData());
                        if (g_cancellable_is_cancelled(cancel.get())) {
                            break;
                        }
                    }
                    Progress progress{this};
                    QMetaObject::invokeMethod(
                        this,
                        [this, name] {
                            current = name;
                            emit changed();
                        },
                        Qt::QueuedConnection);
                    if (transferItem(source, target, cut, cancel.get(), &progress, &error)) {
                        completed.append(urls.at(index));
                    }
                }
                if (error) {
                    errors.append(name + ": " + QString::fromUtf8(error->message));
                    g_clear_error(&error);
                }
                g_object_unref(target);
                g_object_unref(folder);
                g_object_unref(source);
            }
            const bool canceled = g_cancellable_is_cancelled(cancel.get());
            if (canceled) {
                errors.append(QStringLiteral("Transfer canceled; completed items are preserved."));
            }
            QMetaObject::invokeMethod(this, [this, completed] { successes = completed; }, Qt::QueuedConnection);
            return errors.join('\n');
        }));
    }

}
