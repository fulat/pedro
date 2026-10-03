#include <gio/gio.h>

#include <pedro/papi/io/desktop/model.hpp>
#include <pedro/papi/io/content/icon.h>

#include <QCollator>
#include <QPointer>
#include <QCryptographicHash>
#include <QSettings>
#include <QStandardPaths>
#include <QPointF>
#include <cmath>
#include <QSet>
#include <QTimer>
#include <QUrl>

#include <algorithm>
#include <utility>

namespace Pedro::Papi::Io::Desktop {

    namespace {

        constexpr auto attributes = "id::file,standard::name,standard::display-name,standard::type,standard::is-hidden,standard::content-type,standard::size,time::modified";
        QString positionKey(const QString& uri) {

            return QString::fromLatin1(QCryptographicHash::hash(uri.toUtf8(), QCryptographicHash::Sha256).toHex());
        }

        bool validName(const QString& name) {

            return !name.trimmed().isEmpty() && name != "." && name != ".." && !name.contains('/') && !name.contains(QChar::Null);
        }

        bool precedes(const QVariantMap& left, const QVariantMap& right, const QString& key, const QCollator& collator) {

            if (key == "type") {
                const bool leftFolder = left.value("isDirectory").toBool();
                const bool rightFolder = right.value("isDirectory").toBool();
                if (leftFolder != rightFolder) {
                    return leftFolder;
                }

                const int comparison = collator.compare(left.value("type").toString(), right.value("type").toString());
                if (comparison != 0) {
                    return comparison < 0;
                }
            } else if (key == "date" || key == "size") {
                const auto attribute = key == "date" ? "modified" : "size";
                const auto leftValue = left.value(attribute).toULongLong();
                const auto rightValue = right.value(attribute).toULongLong();
                if (leftValue != rightValue) {
                    return leftValue > rightValue;
                }
            }

            const int comparison = collator.compare(left.value("name").toString(), right.value("name").toString());
            return comparison != 0 ? comparison < 0 : left.value("id").toString() < right.value("id").toString();
        }

        constexpr int entryRole = Qt::UserRole + 1;

        QVariantMap value(GFile* file, GFileInfo* info) {

            if (g_file_info_get_is_hidden(info)) {
                return {};
            }

            auto* uri = g_file_get_uri(file);
            const auto url = QUrl(QString::fromUtf8(uri));
            g_free(uri);

            const bool folder = g_file_info_get_file_type(info) == G_FILE_TYPE_DIRECTORY;
            const auto* contentType = g_file_info_get_content_type(info);
            const bool image = contentType && g_content_type_is_a(contentType, "image/*");

            const QString group = folder ? "folder" : image ? "image" : contentType && g_content_type_is_a(contentType, "text/plain") ? "text" : contentType && g_content_type_is_a(contentType, "audio/*") ? "audio" : contentType && g_content_type_is_a(contentType, "video/*") ? "video" : "file";

            const auto* identity = g_file_info_get_attribute_string(info, G_FILE_ATTRIBUTE_ID_FILE);

            const auto type = contentType ? QString::fromUtf8(contentType) : QString{};
            QVariantMap entry;
            entry["id"] = url.toString(QUrl::FullyEncoded);
            entry["identity"] = identity ? QString::fromUtf8(identity) : QString{};
            entry["name"] = QString::fromUtf8(g_file_info_get_display_name(info));
            entry["url"] = url;
            entry["path"] = url.toLocalFile();
            entry["isDirectory"] = folder;
            entry["group"] = group;
            entry["icon"] = folder ? "folder" : image ? "image" : "notes";

            entry["visualType"] = folder ? "folder" : image && url.isLocalFile() ? "image" : "themed";
            entry["contentType"] = type;
            entry["iconNames"] = Pedro::Papi::Io::Content::iconNames(type);

            entry["type"] = type;
            entry["size"] = QVariant::fromValue(g_file_info_get_size(info));
            entry["modified"] = QVariant::fromValue(g_file_info_get_attribute_uint64(info, G_FILE_ATTRIBUTE_TIME_MODIFIED));
            return entry;
        }

    }

    struct Model::State {
            Model* owner;
            QSettings positions{QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + QStringLiteral("/pedro/desktop.ini"), QSettings::IniFormat};
            QString directory;
            QString error;
            bool loading = true;
            QList<QVariantMap> entries;
            GFile* folder = nullptr;
            GFileMonitor* monitor = nullptr;
            GCancellable* cancellable = g_cancellable_new();
            QTimer debounce;
            QSet<QString> pending;
            QHash<QString, quint64> revisions;
            quint64 revision = 0;

            struct Scan {
                    QPointer<Model> model;
                    GFileEnumerator* enumerator = nullptr;
                    QList<QVariantMap> entries;

                    ~Scan() {

                        if (enumerator) {
                            g_file_enumerator_close_async(enumerator, G_PRIORITY_DEFAULT, nullptr, nullptr, nullptr);
                            g_object_unref(enumerator);
                        }
                    }
            };

            struct Query {
                    QPointer<Model> model;
                    QString uri;
                    quint64 revision;
            };

            explicit State(Model* model) : owner(model) {

                debounce.setSingleShot(true);
                debounce.setInterval(100);
                QObject::connect(&debounce, &QTimer::timeout, owner, [this] { flush(); });
            }

            ~State() {

                g_cancellable_cancel(cancellable);

                if (monitor) {
                    g_signal_handlers_disconnect_by_data(monitor, this);
                    g_file_monitor_cancel(monitor);
                    g_object_unref(monitor);
                }

                if (folder) {
                    g_object_unref(folder);
                }

                g_object_unref(cancellable);
            }

            void queue(GFile* file) {

                if (!file) {
                    return;
                }

                auto* parent = g_file_get_parent(file);
                const bool child = parent && g_file_equal(parent, folder);

                if (parent) {
                    g_object_unref(parent);
                }

                if (!child) {
                    return;
                }

                auto* uri = g_file_get_uri(file);
                const auto key = QString::fromUtf8(uri);
                g_free(uri);
                revisions[key] = ++revision;
                pending.insert(key);

                if (!loading && !debounce.isActive()) {
                    debounce.start();
                }
            }

            void flush() {

                const auto changes = std::exchange(pending, {});

                for (const auto& uri : changes) {
                    auto* file = g_file_new_for_uri(uri.toUtf8().constData());
                    auto* query = new Query{owner, uri, revisions.value(uri)};
                    g_file_query_info_async(
                        file, attributes, G_FILE_QUERY_INFO_NONE, G_PRIORITY_DEFAULT, cancellable,
                        [](GObject* source, GAsyncResult* result, gpointer data) {
                            std::unique_ptr<Query> query(static_cast<Query*>(data));
                            GError* error = nullptr;
                            auto* info = g_file_query_info_finish(G_FILE(source), result, &error);

                            if (query->model && query->model->state->revisions.value(query->uri) == query->revision) {
                                if (info) {
                                    query->model->apply(query->uri, value(G_FILE(source), info));
                                } else if (g_error_matches(error, G_IO_ERROR, G_IO_ERROR_NOT_FOUND)) {
                                    query->model->apply(query->uri, {});
                                } else if (!g_error_matches(error, G_IO_ERROR, G_IO_ERROR_CANCELLED)) {
                                    query->model->setError(QString::fromUtf8(error->message));
                                }

                                query->model->state->revisions.remove(query->uri);
                            }

                            if (info) {
                                g_object_unref(info);
                            }

                            g_clear_error(&error);
                        },
                        query);
                    g_object_unref(file);
                }
            }

            struct Operation {
                    QPointer<Model> model;
                    QString name;
                    QString oldId;
                    bool folder = false;
                    int attempt = 1;
                    GFile* file = nullptr;

                    ~Operation() {
                        if (file) {
                            g_object_unref(file);
                        }
                    }
            };

            static void failed(Operation* operation, GError* error) {
                if (operation->model && !g_error_matches(error, G_IO_ERROR, G_IO_ERROR_CANCELLED)) {
                    operation->model->setError(QString::fromUtf8(error->message));
                    emit operation->model->operationFailed(QString::fromUtf8(error->message));
                }
                g_clear_error(&error);
                delete operation;
            }

            static void ready(Operation* operation) {
                if (!operation->model) {
                    delete operation;
                    return;
                }
                g_file_query_info_async(
                    operation->file, attributes, G_FILE_QUERY_INFO_NONE, G_PRIORITY_DEFAULT, operation->model->state->cancellable,
                    [](GObject* source, GAsyncResult* result, gpointer data) {
                        auto* operation = static_cast<Operation*>(data);
                        GError* error = nullptr;
                        auto* info = g_file_query_info_finish(G_FILE(source), result, &error);
                        if (!info) {
                            failed(operation, error);
                            return;
                        }
                        if (operation->model) {
                            const auto entry = value(G_FILE(source), info);
                            auto* uri = g_file_get_uri(G_FILE(source));
                            const auto id = QUrl(QString::fromUtf8(uri)).toString(QUrl::FullyEncoded);
                            g_free(uri);
                            if (!operation->oldId.isEmpty()) {
                                const auto oldKey = positionKey(operation->oldId);
                                for (const auto& prefix : {QString{}, QStringLiteral("layout/grid/"), QStringLiteral("layout/free/")}) {
                                    if (operation->model->state->positions.contains(prefix + oldKey)) {
                                        operation->model->state->positions.setValue(prefix + positionKey(id), operation->model->state->positions.value(prefix + oldKey));
                                    }
                                }
                                operation->model->apply(operation->oldId, {});
                            }
                            operation->model->apply(id, entry);
                            operation->model->setError({});
                            if (operation->oldId.isEmpty()) {
                                emit operation->model->entryCreated(id);
                            } else {
                                emit operation->model->entryRenamed(id);
                            }
                        }
                        g_object_unref(info);
                        delete operation;
                    },
                    operation);
            }

            static void create(Operation* operation) {
                if (!operation->model) {
                    delete operation;
                    return;
                }
                if (operation->file) {
                    g_object_unref(operation->file);
                }
                const auto name = operation->attempt == 1 ? operation->name : operation->name + QStringLiteral(" (%1)").arg(operation->attempt);
                operation->file = g_file_get_child(operation->model->state->folder, name.toUtf8().constData());
                const auto finished = +[](GObject* source, GAsyncResult* result, gpointer data) {
                    auto* operation = static_cast<Operation*>(data);
                    GError* error = nullptr;
                    GFileOutputStream* stream = nullptr;
                    const bool success = operation->folder ? g_file_make_directory_finish(G_FILE(source), result, &error) : (stream = g_file_create_finish(G_FILE(source), result, &error)) != nullptr;
                    if (!success) {
                        if (operation->model && g_error_matches(error, G_IO_ERROR, G_IO_ERROR_EXISTS)) {
                            g_clear_error(&error);
                            ++operation->attempt;
                            create(operation);
                        } else {
                            failed(operation, error);
                        }
                        return;
                    }
                    if (stream) {
                        g_output_stream_close_async(
                            G_OUTPUT_STREAM(stream), G_PRIORITY_DEFAULT, nullptr,
                            [](GObject* source, GAsyncResult* result, gpointer data) {
                                auto* operation = static_cast<Operation*>(data);
                                GError* error = nullptr;
                                if (g_output_stream_close_finish(G_OUTPUT_STREAM(source), result, &error)) {
                                    ready(operation);
                                } else {
                                    failed(operation, error);
                                }
                            },
                            operation);
                        g_object_unref(stream);
                    } else {
                        ready(operation);
                    }
                };
                if (operation->folder) {
                    g_file_make_directory_async(operation->file, G_PRIORITY_DEFAULT, operation->model->state->cancellable, finished, operation);
                } else {
                    g_file_create_async(operation->file, G_FILE_CREATE_NONE, G_PRIORITY_DEFAULT, operation->model->state->cancellable, finished, operation);
                }
            }

            static void next(Scan* scan) {

                g_file_enumerator_next_files_async(
                    scan->enumerator, 128, G_PRIORITY_DEFAULT, scan->model ? scan->model->state->cancellable : nullptr,
                    [](GObject* source, GAsyncResult* result, gpointer data) {
                        auto* scan = static_cast<Scan*>(data);
                        GError* error = nullptr;
                        auto* files = g_file_enumerator_next_files_finish(G_FILE_ENUMERATOR(source), result, &error);

                        if (scan->model && files) {
                            for (auto* item = files; item; item = item->next) {
                                auto* info = G_FILE_INFO(item->data);
                                auto* child = g_file_enumerator_get_child(scan->enumerator, info);
                                const auto entry = value(child, info);
                                g_object_unref(child);

                                if (!entry.isEmpty()) {
                                    scan->entries.append(entry);
                                }
                            }
                        }

                        const bool more = files && !error && scan->model;
                        g_list_free_full(files, g_object_unref);

                        if (more) {
                            next(scan);
                            return;
                        }

                        if (scan->model) {
                            auto* model = scan->model.data();

                            if (error) {
                                model->setError(QString::fromUtf8(error->message));
                            } else {
                                std::sort(scan->entries.begin(), scan->entries.end(), [](const auto& left, const auto& right) { return QString::localeAwareCompare(left.value("name").toString(), right.value("name").toString()) < 0; });

                                for (const auto& entry : scan->entries) {
                                    model->apply(entry.value("id").toString(), entry);
                                }
                            }

                            model->state->loading = false;
                            emit model->loadingChanged();
                            model->state->flush();
                        }

                        g_clear_error(&error);
                        delete scan;
                    },
                    scan);
            }
    };

    Model::Model(QObject* parent) : QAbstractListModel(parent), state(std::make_unique<State>(this)) {

        // Start each session with the user's manual layout and no selected sort.
        if (!sortKey().isEmpty() && state->positions.contains("organization/undo/positions")) {
            const auto snapshot = state->positions.value("organization/undo/positions").toMap();
            state->positions.remove("layout");
            for (auto it = snapshot.cbegin(); it != snapshot.cend(); ++it) {
                state->positions.setValue(it.key(), it.value());
            }
        }
        state->positions.setValue("organization/sort", QString());

        const auto* desktop = g_get_user_special_dir(G_USER_DIRECTORY_DESKTOP);

        if (!desktop || !*desktop) {
            setError(QStringLiteral("XDG Desktop directory is unavailable"));
            state->loading = false;
            return;
        }

        state->directory = QString::fromUtf8(desktop);
        state->folder = g_file_new_for_path(desktop);
        GError* error = nullptr;
        state->monitor = g_file_monitor_directory(state->folder, G_FILE_MONITOR_WATCH_MOVES, state->cancellable, &error);

        if (state->monitor) {
            g_signal_connect(state->monitor, "changed", G_CALLBACK(+[](GFileMonitor*, GFile* file, GFile* other, GFileMonitorEvent event, gpointer data) {
                                 auto* state = static_cast<State*>(data);
                                 if (event == G_FILE_MONITOR_EVENT_RENAMED && file && other) {
                                     auto* oldUri = g_file_get_uri(file);
                                     auto* newUri = g_file_get_uri(other);
                                     const auto oldKey = positionKey(QString::fromUtf8(oldUri));
                                     const auto newKey = positionKey(QString::fromUtf8(newUri));

                                     for (const auto& prefix : {QString{}, QStringLiteral("layout/grid/"), QStringLiteral("layout/free/")}) {
                                         if (state->positions.contains(prefix + oldKey)) {
                                             state->positions.setValue(prefix + newKey, state->positions.value(prefix + oldKey));
                                             state->positions.remove(prefix + oldKey);
                                         }
                                     }

                                     g_free(oldUri);
                                     g_free(newUri);
                                 }

                                 state->queue(file);
                                 state->queue(other);
                             }),
                             state.get());
        } else {
            setError(QString::fromUtf8(error->message));
            g_clear_error(&error);
        }

        auto* scan = new State::Scan{this};
        g_file_enumerate_children_async(
            state->folder, attributes, G_FILE_QUERY_INFO_NONE, G_PRIORITY_DEFAULT, state->cancellable,
            [](GObject* source, GAsyncResult* result, gpointer data) {
                auto* scan = static_cast<State::Scan*>(data);
                GError* error = nullptr;
                scan->enumerator = g_file_enumerate_children_finish(G_FILE(source), result, &error);

                if (scan->model && scan->enumerator) {
                    State::next(scan);
                } else {
                    if (scan->model) {
                        scan->model->setError(QString::fromUtf8(error->message));
                        scan->model->state->loading = false;
                        emit scan->model->loadingChanged();
                    }

                    delete scan;
                }

                g_clear_error(&error);
            },
            scan);
    }

    Model::~Model() = default;

    int Model::rowCount(const QModelIndex& parent) const {

        return parent.isValid() ? 0 : state->entries.size();
    }

    QVariant Model::data(const QModelIndex& index, int role) const {

        if (!index.isValid() || index.row() < 0 || index.row() >= state->entries.size() || role != entryRole) {
            return {};
        }

        return state->entries.at(index.row());
    }

    QHash<int, QByteArray> Model::roleNames() const {

        return {{entryRole, "entry"}};
    }

    QString Model::directory() const {

        return state->directory;
    }

    QString Model::error() const {

        return state->error;
    }

    bool Model::loading() const {

        return state->loading;
    }

    void Model::setError(const QString& error) {

        if (state->error != error) {
            state->error = error;
            emit errorChanged();
        }
    }

    QString Model::organization() const {
        const auto mode = state->positions.value("organization/mode", "grid").toString();
        return mode == "free" || mode == "stack" ? mode : QStringLiteral("grid");
    }

    bool Model::keepAligned() const {
        return state->positions.value("organization/aligned", true).toBool();
    }

    void Model::setOrganization(const QString& mode) {
        if (mode != "grid" && mode != "free" && mode != "stack") {
            return;
        }
        state->positions.setValue("organization/mode", mode);
        state->positions.setValue("organization/aligned", mode != "free");
        const auto entries = state->entries;
        for (const auto& entry : entries) {
            apply(entry.value("id").toString(), entry);
        }
        emit organizationChanged();
    }

    void Model::setKeepAligned(bool enabled) {
        state->positions.setValue("organization/aligned", enabled);
        emit organizationChanged();
    }

    QString Model::sortKey() const {

        const auto key = state->positions.value("organization/sort", "").toString();
        return key == "name" || key == "type" || key == "date" || key == "size" ? key : QString();
    }

    void Model::sort(const QString& key) {

        if (key != "name" && key != "type" && key != "date" && key != "size") {
            return;
        }

        const auto active = sortKey();
        if (active == key) {
            const auto snapshot = state->positions.value("organization/undo/positions").toMap();
            if (state->positions.contains("organization/undo/positions")) {
                state->positions.remove("layout");
                for (auto it = snapshot.cbegin(); it != snapshot.cend(); ++it) {
                    state->positions.setValue(it.key(), it.value());
                }
            }
            state->positions.setValue("organization/sort", QString());
            const auto entries = state->entries;
            for (const auto& entry : entries) {
                apply(entry.value("id").toString(), entry);
            }
            reorder();
            emit sortChanged();
            emit groupsChanged();
            emit sortRestored();
            return;
        }

        if (active.isEmpty()) {
            QVariantMap snapshot;
            for (const auto& setting : state->positions.allKeys()) {
                if (setting.startsWith("layout/")) {
                    snapshot.insert(setting, state->positions.value(setting));
                }
            }
            QStringList order;
            for (const auto& entry : state->entries) {
                order.append(entry.value("id").toString());
            }
            state->positions.setValue("organization/undo/positions", snapshot);
            state->positions.setValue("organization/undo/order", order);
        }
        state->positions.setValue("organization/sort", key);
        reorder();
        emit sortChanged();
        emit groupsChanged();
        emit sortRequested();
    }

    void Model::reorder() {

        QCollator collator;
        collator.setNumericMode(true);
        collator.setCaseSensitivity(Qt::CaseInsensitive);
        const auto key = sortKey();
        auto ordered = state->entries;
        const auto manualOrder = state->positions.value("organization/undo/order").toStringList();
        std::stable_sort(ordered.begin(), ordered.end(), [&key, &collator, &manualOrder](const auto& left, const auto& right) {
            if (key.isEmpty() && !manualOrder.isEmpty()) {
                const auto leftIndex = manualOrder.indexOf(left.value("id").toString());
                const auto rightIndex = manualOrder.indexOf(right.value("id").toString());
                if (leftIndex != rightIndex) {
                    return leftIndex >= 0 && (rightIndex < 0 || leftIndex < rightIndex);
                }
            }
            return precedes(left, right, key, collator);
        });

        for (int target = 0; target < ordered.size(); ++target) {
            const auto id = ordered.at(target).value("id").toString();
            int source = target;
            while (source < state->entries.size() && state->entries.at(source).value("id").toString() != id) {
                ++source;
            }

            if (source != target && source < state->entries.size()) {
                beginMoveRows({}, source, source, {}, target);
                state->entries.move(source, target);
                endMoveRows();
            }
        }
    }

    QVariantList Model::groups() const {

        QMap<QString, QStringList> members;
        QStringList keys;

        for (const auto& entry : state->entries) {
            const auto key = entry.value("group").toString();
            if (!members.contains(key)) {
                keys.append(key);
            }
            members[key].append(entry.value("id").toString());
        }

        QVariantList groups;
        for (const auto& key : keys) {
            groups.append(QVariantMap{{"key", key}, {"members", members.value(key)}});
        }
        return groups;
    }

    void Model::createFolder(const QString& name) {
        if (!state->folder || !validName(name)) {
            emit operationFailed(QStringLiteral("Invalid folder name"));
            return;
        }
        auto* operation = new State::Operation{this, name};
        operation->folder = true;
        State::create(operation);
    }

    void Model::createFile(const QString& name) {
        if (!state->folder || !validName(name)) {
            emit operationFailed(QStringLiteral("Invalid file name"));
            return;
        }
        State::create(new State::Operation{this, name});
    }

    void Model::renameEntry(const QString& id, const QString& name) {
        if (!validName(name)) {
            emit operationFailed(QStringLiteral("Invalid file name"));
            return;
        }
        for (const auto& entry : state->entries) {
            if (entry.value("id").toString() != id) {
                continue;
            }
            auto* operation = new State::Operation{this, name, id};
            operation->file = g_file_new_for_uri(id.toUtf8().constData());
            g_file_set_display_name_async(
                operation->file, name.toUtf8().constData(), G_PRIORITY_DEFAULT, state->cancellable,
                [](GObject* source, GAsyncResult* result, gpointer data) {
                    auto* operation = static_cast<State::Operation*>(data);
                    GError* error = nullptr;
                    auto* renamed = g_file_set_display_name_finish(G_FILE(source), result, &error);
                    if (!renamed) {
                        State::failed(operation, error);
                        return;
                    }
                    g_object_unref(operation->file);
                    operation->file = renamed;
                    State::ready(operation);
                },
                operation);
            return;
        }
        emit operationFailed(QStringLiteral("The desktop entry no longer exists"));
    }

    void Model::savePosition(const QString& id, double x, double y, bool manual) {

        if (organization() == "stack" || !std::isfinite(x) || !std::isfinite(y) || x < 0 || y < 0) {
            return;
        }

        for (const auto& entry : state->entries) {
            if (entry.value("id").toString() == id) {
                const auto prefix = QStringLiteral("layout/%1/").arg(organization());
                state->positions.setValue(prefix + positionKey(id), QPointF(x, y));
                const auto identity = entry.value("identity").toString();

                if (!identity.isEmpty()) {
                    state->positions.setValue(prefix + positionKey(identity), QPointF(x, y));
                }
                // A manual move becomes this icon's new baseline for sort undo.
                if (manual && !sortKey().isEmpty()) {
                    auto snapshot = state->positions.value("organization/undo/positions").toMap();
                    snapshot.insert(prefix + positionKey(id), QPointF(x, y));
                    if (!identity.isEmpty()) {
                        snapshot.insert(prefix + positionKey(identity), QPointF(x, y));
                    }
                    state->positions.setValue("organization/undo/positions", snapshot);
                }
                apply(id, entry);
                return;
            }
        }
    }

    void Model::apply(const QString& uri, const QVariantMap& value) {

        auto entry = value;

        const auto identity = entry.value("identity").toString();
        const auto prefix = QStringLiteral("layout/%1/").arg(organization() == "free" ? "free" : "grid");
        auto key = !identity.isEmpty() && state->positions.contains(prefix + positionKey(identity)) ? prefix + positionKey(identity) : prefix + positionKey(uri);
        if (!state->positions.contains(key)) {
            key = !identity.isEmpty() && state->positions.contains(positionKey(identity)) ? positionKey(identity) : positionKey(uri);
        }
        entry.remove(QStringLiteral("position"));

        if (!entry.isEmpty() && state->positions.contains(key)) {
            const auto position = state->positions.value(key).toPointF();
            entry.insert(QStringLiteral("position"), QVariantMap{{"x", position.x()}, {"y", position.y()}});
        }

        for (int row = 0; row < state->entries.size(); ++row) {
            if (state->entries.at(row).value("id").toString() != uri) {
                continue;
            }

            if (entry.isEmpty()) {
                beginRemoveRows({}, row, row);
                state->entries.removeAt(row);
                endRemoveRows();
                emit groupsChanged();
            } else if (state->entries.at(row) != entry) {
                const auto previous = state->entries.at(row);
                state->entries[row] = entry;
                emit dataChanged(index(row), index(row), {entryRole});
                if (previous.value("name") != entry.value("name") || previous.value("type") != entry.value("type") || previous.value("size") != entry.value("size") || previous.value("modified") != entry.value("modified")) {
                    reorder();
                }
                emit groupsChanged();
            }

            return;
        }

        if (!entry.isEmpty()) {
            const auto row = state->entries.size();
            beginInsertRows({}, row, row);
            state->entries.append(entry);
            endInsertRows();
            reorder();
            emit groupsChanged();
        }
    }

}
