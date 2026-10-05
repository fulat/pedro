#include <gio/gio.h>

#include <pedro/papi/io/trash/manager.h>

#include <QFutureWatcher>
#include <QSet>
#include <QUrl>
#include <QtConcurrent>

namespace Pedro::Papi::Io::Trash {

    namespace {

        bool isTrashItem(GFile* file) {

            auto* root = g_file_new_for_uri("trash:///");
            auto* parent = g_file_get_parent(file);
            const bool result = parent && g_file_equal(parent, root);
            g_clear_object(&parent);
            g_object_unref(root);
            return result;
        }

        bool restoreItem(GFile* file, GError** error) {

            auto* info = g_file_query_info(file, G_FILE_ATTRIBUTE_TRASH_ORIG_PATH, G_FILE_QUERY_INFO_NOFOLLOW_SYMLINKS, nullptr, error);
            if (!info) {
                return false;
            }

            const auto* path = g_file_info_get_attribute_byte_string(info, G_FILE_ATTRIBUTE_TRASH_ORIG_PATH);
            if (!path || !g_path_is_absolute(path)) {
                g_set_error_literal(error, G_IO_ERROR, G_IO_ERROR_INVALID_ARGUMENT, "The original location is unavailable.");
                g_object_unref(info);
                return false;
            }

            auto* target = g_file_new_for_path(path);
            auto* parent = g_file_get_parent(target);
            bool success = true;
            if (parent && !g_file_make_directory_with_parents(parent, nullptr, error)) {
                if (g_error_matches(*error, G_IO_ERROR, G_IO_ERROR_EXISTS)) {
                    g_clear_error(error);
                } else {
                    success = false;
                }
            }
            if (success) {
                success = g_file_move(file, target, G_FILE_COPY_NONE, nullptr, nullptr, nullptr, error);
            }

            g_clear_object(&parent);
            g_object_unref(target);
            g_object_unref(info);
            return success;
        }

    }

    Manager::Manager(QObject* parent) : QObject(parent) {
    }

    bool Manager::busy() const {
        return active;
    }

    QString Manager::error() const {
        return failure;
    }

    void Manager::move(const QVariantList& urls) {
        run(Operation::Move, urls);
    }

    void Manager::restore(const QVariantList& urls) {
        run(Operation::Restore, urls);
    }

    void Manager::remove(const QVariantList& urls) {
        run(Operation::Remove, urls);
    }

    void Manager::empty() {
        run(Operation::Empty, {});
    }

    void Manager::run(Operation operation, const QVariantList& urls) {

        if (active || (urls.isEmpty() && operation != Operation::Empty)) {
            return;
        }

        active = true;
        failure.clear();
        emit changed();
        auto* watcher = new QFutureWatcher<QString>(this);
        connect(watcher, &QFutureWatcher<QString>::finished, this, [this, watcher] {
            failure = watcher->result();
            active = false;
            watcher->deleteLater();
            emit changed();
            if (!failure.isEmpty()) {
                emit failed(failure);
            }
        });
        watcher->setFuture(QtConcurrent::run([operation, urls] {
            QStringList locations;
            QStringList errors;
            QSet<QString> seen;
            for (const auto& value : urls) {
                const auto url = value.toUrl();
                const auto address = url.toString(QUrl::FullyEncoded);
                if (!seen.contains(address)) {
                    seen.insert(address);
                    locations.append(address);
                }
            }

            if (operation == Operation::Empty) {
                auto* root = g_file_new_for_uri("trash:///");
                GError* error = nullptr;
                auto* enumerator = g_file_enumerate_children(root, G_FILE_ATTRIBUTE_STANDARD_NAME, G_FILE_QUERY_INFO_NOFOLLOW_SYMLINKS, nullptr, &error);
                if (enumerator) {
                    while (auto* info = g_file_enumerator_next_file(enumerator, nullptr, &error)) {
                        auto* child = g_file_get_child(root, g_file_info_get_name(info));
                        auto* address = g_file_get_uri(child);
                        locations.append(QString::fromUtf8(address));
                        g_free(address);
                        g_object_unref(child);
                        g_object_unref(info);
                    }
                    g_object_unref(enumerator);
                }
                g_object_unref(root);
                if (error) {
                    const auto message = QString::fromUtf8(error->message);
                    g_error_free(error);
                    return message;
                }
            }

            for (const auto& address : locations) {
                const QUrl url(address);
                auto* file = g_file_new_for_uri(address.toUtf8().constData());
                GError* error = nullptr;
                bool success = false;
                if (operation == Operation::Move && url.isLocalFile() && url.toLocalFile() != "/") {
                    success = g_file_trash(file, nullptr, &error);
                } else if (operation != Operation::Move && isTrashItem(file)) {
                    success = operation == Operation::Restore ? restoreItem(file, &error) : g_file_delete(file, nullptr, &error);
                }
                if (!success && errors.size() < 20) {
                    errors.append(url.fileName() + ": " + (error ? QString::fromUtf8(error->message) : QStringLiteral("Invalid location for this Trash operation.")));
                }
                g_clear_error(&error);
                g_object_unref(file);
            }
            return errors.join('\n');
        }));
    }

}
