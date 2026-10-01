#include <gio/gio.h>

#include <pedro/papi/io/directory/model.hpp>

#include <QDateTime>
#include <QFile>
#include <QFutureWatcher>
#include <QSet>
#include <QSortFilterProxyModel>
#include <QStringList>
#include <QTimer>
#include <QUrl>
#include <QtConcurrent>

#include <algorithm>

namespace Pedro::Papi::Io::Directory {

    namespace {

        constexpr int entryRole = Qt::UserRole + 1;
        constexpr auto attributes = "standard::name,standard::display-name,standard::type,standard::is-hidden,standard::content-type,standard::size,time::modified";

        class Filter : public QSortFilterProxyModel {
            public:

                explicit Filter(bool folders) : folders(folders) {
                }

            protected:

                bool filterAcceptsRow(int row, const QModelIndex& parent) const override {
                    return sourceModel()->data(sourceModel()->index(row, 0, parent), entryRole).toMap().value("isDirectory").toBool() == folders;
                }

            private:

                bool folders;
        };

        using Cancellation = std::shared_ptr<GCancellable>;

        struct Snapshot {
                QList<QVariantMap> entries;
                QString error;
        };

        GUserDirectory specialDirectory(const QString& place) {

            if (place == "desktop") {
                return G_USER_DIRECTORY_DESKTOP;
            }
            if (place == "documents") {
                return G_USER_DIRECTORY_DOCUMENTS;
            }
            if (place == "downloads") {
                return G_USER_DIRECTORY_DOWNLOAD;
            }
            if (place == "images") {
                return G_USER_DIRECTORY_PICTURES;
            }
            if (place == "music") {
                return G_USER_DIRECTORY_MUSIC;
            }
            if (place == "videos") {
                return G_USER_DIRECTORY_VIDEOS;
            }
            if (place == "public") {
                return G_USER_DIRECTORY_PUBLIC_SHARE;
            }
            return G_USER_N_DIRECTORIES;
        }

        QString uri(GFile* file) {

            auto* value = g_file_get_uri(file);
            const auto result = QString::fromUtf8(value);
            g_free(value);
            return result;
        }

        QString formatSize(goffset size) {

            static const QStringList units{"B", "KB", "MB", "GB", "TB"};
            double amount = size;
            int index = 0;
            while (amount >= 1024 && index + 1 < units.size()) {
                amount /= 1024;
                ++index;
            }
            return QString::number(amount, 'f', index == 0 ? 0 : 1) + ' ' + units.at(index);
        }

        QVariantMap entry(GFile* file, GFileInfo* info) {

            const auto* contentType = g_file_info_get_content_type(info);
            auto* description = contentType ? g_content_type_get_description(contentType) : nullptr;
            const bool folder = g_file_info_get_file_type(info) == G_FILE_TYPE_DIRECTORY;
            const auto address = uri(file);
            const auto size = g_file_info_get_size(info);
            const auto modified = g_file_info_get_attribute_uint64(info, G_FILE_ATTRIBUTE_TIME_MODIFIED);
            QVariantMap result;
            result["id"] = address;
            result["url"] = address;
            result["path"] = QUrl(address).isLocalFile() ? QUrl(address).toLocalFile() : QUrl(address).toDisplayString();
            result["name"] = QString::fromUtf8(g_file_info_get_display_name(info));
            result["isDirectory"] = folder;
            result["icon"] = folder ? "folder" : contentType && g_content_type_is_a(contentType, "image/*") ? "image" : "file";
            result["type"] = description ? QString::fromUtf8(description) : QString{};
            result["size"] = QVariant::fromValue(size);
            result["sizeText"] = folder ? QString{} : formatSize(size);
            result["modified"] = QDateTime::fromSecsSinceEpoch(modified);
            result["modifiedText"] = QDateTime::fromSecsSinceEpoch(modified).toString("yyyy-MM-dd HH:mm");
            g_free(description);
            return result;
        }

        void append(Snapshot& snapshot, const QString& address, GCancellable* cancel) {

            auto* file = g_file_new_for_uri(address.toUtf8().constData());
            auto* info = g_file_query_info(file, attributes, G_FILE_QUERY_INFO_NONE, cancel, nullptr);
            if (info) {
                snapshot.entries.append(entry(file, info));
                g_object_unref(info);
            }
            g_object_unref(file);
        }

        Snapshot scan(const QString& address, const QString& place, const Cancellation& cancel) {

            Snapshot snapshot;
            if (place == "home") {
                // GLib resolves the active user's configured XDG directories in every session.
                for (int index = 0; index < G_USER_N_DIRECTORIES; ++index) {
                    const auto* path = g_get_user_special_dir(static_cast<GUserDirectory>(index));
                    if (path && *path && !g_cancellable_is_cancelled(cancel.get())) {
                        auto* directory = g_file_new_for_path(path);
                        GError* error = nullptr;
                        g_file_make_directory_with_parents(directory, cancel.get(), &error);
                        if (error && !g_error_matches(error, G_IO_ERROR, G_IO_ERROR_EXISTS)) {
                            snapshot.error = QString::fromUtf8(error->message);
                        }
                        g_clear_error(&error);
                        g_object_unref(directory);
                    }
                }
            }

            if (place == "favorites") {
                QSet<QString> seen;
                for (const auto& version : {QStringLiteral("gtk-3.0"), QStringLiteral("gtk-4.0")}) {
                    QFile bookmarks(QString::fromUtf8(g_get_user_config_dir()) + '/' + version + "/bookmarks");
                    if (!bookmarks.open(QIODevice::ReadOnly)) {
                        continue;
                    }
                    while (!bookmarks.atEnd() && !g_cancellable_is_cancelled(cancel.get())) {
                        const auto line = QString::fromUtf8(bookmarks.readLine()).trimmed();
                        const auto value = line.section(' ', 0, 0);
                        const auto label = line.section(' ', 1).trimmed();
                        if (!value.isEmpty() && !seen.contains(value)) {
                            seen.insert(value);
                            const auto count = snapshot.entries.size();
                            append(snapshot, value, cancel.get());
                            if (!label.isEmpty() && snapshot.entries.size() > count) {
                                snapshot.entries.last()["name"] = label;
                            }
                        }
                    }
                }
            } else if (place == "recent") {
                auto* bookmarks = g_bookmark_file_new();
                const auto path = QString::fromUtf8(g_get_user_data_dir()) + "/recently-used.xbel";
                GError* error = nullptr;
                if (g_bookmark_file_load_from_file(bookmarks, path.toUtf8().constData(), &error)) {
                    gsize length = 0;
                    auto** addresses = g_bookmark_file_get_uris(bookmarks, &length);
                    for (gsize index = 0; index < length && !g_cancellable_is_cancelled(cancel.get()); ++index) {
                        const auto count = snapshot.entries.size();
                        append(snapshot, QString::fromUtf8(addresses[index]), cancel.get());
                        auto* visited = g_bookmark_file_get_visited_date_time(bookmarks, addresses[index], nullptr);
                        if (visited) {
                            if (snapshot.entries.size() > count) {
                                snapshot.entries.last()["recentTime"] = QVariant::fromValue(g_date_time_to_unix(visited));
                            }
                        }
                    }
                    g_strfreev(addresses);
                } else if (!g_error_matches(error, G_FILE_ERROR, G_FILE_ERROR_NOENT)) {
                    snapshot.error = QString::fromUtf8(error->message);
                }
                g_clear_error(&error);
                g_bookmark_file_free(bookmarks);
            } else if (place == "computer") {
                append(snapshot, QUrl::fromLocalFile("/").toString(), cancel.get());
                auto* volumes = g_volume_monitor_get();
                auto* mounts = g_volume_monitor_get_mounts(volumes);
                QSet<QString> seen{QUrl::fromLocalFile("/").toString()};
                for (auto* node = mounts; node && !g_cancellable_is_cancelled(cancel.get()); node = node->next) {
                    auto* root = g_mount_get_root(G_MOUNT(node->data));
                    const auto address = uri(root);
                    if (!seen.contains(address)) {
                        append(snapshot, address, cancel.get());
                        seen.insert(address);
                    }
                    g_object_unref(root);
                }
                g_list_free_full(mounts, g_object_unref);
                g_object_unref(volumes);
            } else {
                auto* directory = g_file_new_for_uri(address.toUtf8().constData());
                if (specialDirectory(place) != G_USER_N_DIRECTORIES) {
                    GError* creationError = nullptr;
                    g_file_make_directory_with_parents(directory, cancel.get(), &creationError);
                    if (creationError && !g_error_matches(creationError, G_IO_ERROR, G_IO_ERROR_EXISTS)) {
                        snapshot.error = QString::fromUtf8(creationError->message);
                    }
                    g_clear_error(&creationError);
                }
                GError* error = nullptr;
                auto* enumerator = g_file_enumerate_children(directory, attributes, G_FILE_QUERY_INFO_NONE, cancel.get(), &error);
                if (enumerator) {
                    while (!g_cancellable_is_cancelled(cancel.get())) {
                        auto* info = g_file_enumerator_next_file(enumerator, cancel.get(), &error);
                        if (!info) {
                            break;
                        }
                        if (!g_file_info_get_is_hidden(info)) {
                            auto* child = g_file_enumerator_get_child(enumerator, info);
                            snapshot.entries.append(entry(child, info));
                            g_object_unref(child);
                        }
                        g_object_unref(info);
                    }
                    g_file_enumerator_close(enumerator, nullptr, nullptr);
                    g_object_unref(enumerator);
                }
                if (error && !g_error_matches(error, G_IO_ERROR, G_IO_ERROR_CANCELLED)) {
                    snapshot.error = QString::fromUtf8(error->message);
                }
                g_clear_error(&error);
                g_object_unref(directory);
            }
            std::sort(snapshot.entries.begin(), snapshot.entries.end(), [&place](const auto& left, const auto& right) {
                if (place == "recent" && left.value("recentTime") != right.value("recentTime")) {
                    return left.value("recentTime").toLongLong() > right.value("recentTime").toLongLong();
                }
                if (left.value("isDirectory") != right.value("isDirectory")) {
                    return left.value("isDirectory").toBool();
                }
                return QString::localeAwareCompare(left.value("name").toString(), right.value("name").toString()) < 0;
            });
            return snapshot;
        }
    }

    struct Model::State {
            QList<QVariantMap> entries;
            Filter folders{true};
            Filter files{false};
            QString location;
            QString place;
            QString error;
            bool loading = false;
            int cursor = -1;
            QList<QPair<QString, QString>> history;
            quint64 generation = 0;
            Cancellation cancel;
            QList<GFileMonitor*> monitors;
            GVolumeMonitor* volumes = nullptr;
            QTimer debounce;

            void clearMonitors() {

                for (auto* monitor : monitors) {
                    g_signal_handlers_disconnect_by_data(monitor, this);
                    g_file_monitor_cancel(monitor);
                    g_object_unref(monitor);
                }
                monitors.clear();
            }

            ~State() {

                if (cancel) {
                    g_cancellable_cancel(cancel.get());
                }
                clearMonitors();
                if (volumes) {
                    g_signal_handlers_disconnect_by_data(volumes, this);
                    g_object_unref(volumes);
                }
            }
    };

    Model::Model(QObject* parent) : QAbstractListModel(parent), state(std::make_unique<State>()) {

        state->folders.setSourceModel(this);
        state->files.setSourceModel(this);
        state->debounce.setSingleShot(true);
        state->debounce.setInterval(120);
        connect(&state->debounce, &QTimer::timeout, this, &Model::refresh);
        state->volumes = g_volume_monitor_get();
        for (const auto* event : {"mount-added", "mount-removed", "mount-changed"}) {
            g_signal_connect(state->volumes, event, G_CALLBACK(+[](GVolumeMonitor*, GMount*, gpointer data) {
                                 auto* model = static_cast<Model*>(data);
                                 if (model->place() == "computer") {
                                     model->state->debounce.start();
                                 }
                             }),
                             this);
        }
        openPlace("home");
    }

    Model::~Model() {

        g_signal_handlers_disconnect_by_data(state->volumes, this);
    }

    int Model::rowCount(const QModelIndex& parent) const {

        return parent.isValid() ? 0 : state->entries.size();
    }

    QVariant Model::data(const QModelIndex& index, int role) const {

        return index.isValid() && index.row() >= 0 && index.row() < state->entries.size() && role == entryRole ? QVariant(state->entries.at(index.row())) : QVariant{};
    }

    QHash<int, QByteArray> Model::roleNames() const {

        return {{entryRole, "entry"}};
    }

    QString Model::location() const {
        return state->location;
    }

    QString Model::path() const {

        const QUrl address(state->location);
        return address.isLocalFile() ? address.toLocalFile() : state->place == "trash" || address.scheme() == "pedro" ? QString{} : address.toDisplayString();
    }

    QString Model::place() const {
        return state->place;
    }

    QString Model::name() const {
        return QUrl(state->location).fileName(QUrl::FullyDecoded);
    }

    QString Model::error() const {
        return state->error;
    }

    bool Model::loading() const {
        return state->loading;
    }

    bool Model::canGoBack() const {
        return state->cursor > 0;
    }

    bool Model::canGoForward() const {
        return state->cursor + 1 < state->history.size();
    }

    QAbstractItemModel* Model::folderModel() {
        return &state->folders;
    }

    QAbstractItemModel* Model::fileModel() {
        return &state->files;
    }

    QVariantList Model::folders() const {

        QVariantList result;
        for (const auto& item : state->entries) {
            if (item.value("isDirectory").toBool()) {
                result.append(item);
            }
        }
        return result;
    }

    QVariantList Model::files() const {

        QVariantList result;
        for (const auto& item : state->entries) {
            if (!item.value("isDirectory").toBool()) {
                result.append(item);
            }
        }
        return result;
    }

    void Model::openPlace(const QString& place) {

        QString address;
        if (place == "home") {
            address = QUrl::fromLocalFile(QString::fromUtf8(g_get_home_dir())).toString();
        } else if (place == "trash") {
            address = "trash:///";
        } else if (place == "computer" || place == "favorites" || place == "recent") {
            address = "pedro:" + place;
        } else {
            const auto special = specialDirectory(place);
            const auto* path = special == G_USER_N_DIRECTORIES ? nullptr : g_get_user_special_dir(special);
            if (!path || !*path) {
                state->error = QStringLiteral("XDG user directory is unavailable");
                emit contentsChanged();
                return;
            }
            address = QUrl::fromLocalFile(QString::fromUtf8(path)).toString();
        }
        navigate(address, place, true);
    }

    void Model::open(const QString& address) {

        const QUrl url(address);
        if (url.isValid() && (url.isLocalFile() || url.scheme() == "trash" || url.scheme() == "smb" || url.scheme() == "mtp" || url.scheme() == "afp" || url.scheme() == "sftp" || url.scheme() == "dav" || url.scheme() == "davs")) {
            navigate(address, {}, true);
        }
    }

    void Model::goBack() {

        if (canGoBack()) {
            const auto target = state->history.at(--state->cursor);
            navigate(target.first, target.second, false);
        }
    }

    void Model::goForward() {

        if (canGoForward()) {
            const auto target = state->history.at(++state->cursor);
            navigate(target.first, target.second, false);
        }
    }

    void Model::navigate(const QString& address, const QString& place, bool record) {

        state->debounce.stop();
        state->clearMonitors();
        if (record) {
            state->history = state->history.mid(0, state->cursor + 1);
            state->history.append({address, place});
            state->cursor = state->history.size() - 1;
        }
        state->location = address;
        state->place = place;
        beginResetModel();
        state->entries.clear();
        endResetModel();
        emit locationChanged();
        refresh();
    }

    void Model::refresh() {

        if (state->cancel) {
            g_cancellable_cancel(state->cancel.get());
        }
        state->cancel = Cancellation(g_cancellable_new(), [](auto* value) { g_object_unref(value); });
        const auto generation = ++state->generation;
        state->loading = true;
        state->error.clear();
        emit contentsChanged();
        auto* watcher = new QFutureWatcher<Snapshot>(this);
        connect(watcher, &QFutureWatcher<Snapshot>::finished, this, [this, watcher, generation] {
            const auto snapshot = watcher->result();
            watcher->deleteLater();
            if (generation != state->generation) {
                return;
            }
            // Reconcile by URI so monitor events do not reset the entire item model.
            QSet<QString> ids;
            for (const auto& item : snapshot.entries) {
                ids.insert(item.value("id").toString());
            }
            for (int row = state->entries.size() - 1; row >= 0; --row) {
                if (!ids.contains(state->entries.at(row).value("id").toString())) {
                    beginRemoveRows({}, row, row);
                    state->entries.removeAt(row);
                    endRemoveRows();
                }
            }
            for (int row = 0; row < snapshot.entries.size(); ++row) {
                const auto& item = snapshot.entries.at(row);
                int existing = -1;
                for (int index = row; index < state->entries.size(); ++index) {
                    if (state->entries.at(index).value("id") == item.value("id")) {
                        existing = index;
                        break;
                    }
                }
                if (existing < 0) {
                    beginInsertRows({}, row, row);
                    state->entries.insert(row, item);
                    endInsertRows();
                } else {
                    if (existing != row) {
                        beginMoveRows({}, existing, existing, {}, row);
                        state->entries.move(existing, row);
                        endMoveRows();
                    }
                    if (state->entries.at(row) != item) {
                        state->entries[row] = item;
                        emit dataChanged(index(row), index(row), {entryRole});
                    }
                }
            }
            state->error = snapshot.error;
            state->loading = false;
            watch();
            emit contentsChanged();
        });
        watcher->setFuture(QtConcurrent::run(scan, state->location, state->place, state->cancel));
    }

    void Model::watch() {

        if (state->monitors.isEmpty()) {
            QStringList addresses;
            if (state->place == "favorites") {
                for (const auto& version : {QStringLiteral("gtk-3.0"), QStringLiteral("gtk-4.0")}) {
                    addresses.append(QUrl::fromLocalFile(QString::fromUtf8(g_get_user_config_dir()) + '/' + version).toString());
                }
            } else if (state->place == "recent") {
                addresses.append(QUrl::fromLocalFile(QString::fromUtf8(g_get_user_data_dir())).toString());
            } else if (state->place != "computer") {
                addresses.append(state->location);
            }
            for (const auto& address : addresses) {
                auto* folder = g_file_new_for_uri(address.toUtf8().constData());
                auto* monitor = g_file_monitor_directory(folder, G_FILE_MONITOR_WATCH_MOVES, nullptr, nullptr);
                if (monitor) {
                    g_signal_connect(monitor, "changed", G_CALLBACK(+[](GFileMonitor*, GFile*, GFile*, GFileMonitorEvent, gpointer data) { static_cast<State*>(data)->debounce.start(); }), state.get());
                    state->monitors.append(monitor);
                }
                g_object_unref(folder);
            }
        }
    }
}
