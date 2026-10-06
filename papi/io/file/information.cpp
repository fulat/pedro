#include <gio/gio.h>

#include <pedro/papi/io/file/information.h>

#include <QDateTime>
#include <QFutureWatcher>
#include <QtConcurrentRun>

namespace Pedro::Papi::Io::File {

    Information::Information(QObject* parent) : QObject(parent) {
        connect(&watch, &Watch::changed, this, &Information::refresh);
        connect(&watch, &Watch::relocated, this, [this](const QUrl&, const QUrl& destination) { setSource(destination); });
    }

    Information::~Information() {
        if (cancellation) {
            g_cancellable_cancel(cancellation.get());
        }
    }

    QUrl Information::source() const {
        return currentSource;
    }
    QVariantMap Information::data() const {
        return values;
    }
    bool Information::loading() const {
        return busy;
    }
    QString Information::error() const {
        return failure;
    }

    void Information::setSource(const QUrl& source) {
        if (source == currentSource) {
            return;
        }
        currentSource = source;
        values.clear();
        watch.open(source);
        refresh();
    }

    void Information::refresh() {
        if (cancellation) {
            g_cancellable_cancel(cancellation.get());
        }
        const auto request = ++generation;
        failure.clear();
        busy = !currentSource.isEmpty();
        if (!busy) {
            values.clear();
            emit changed();
            return;
        }
        cancellation = std::shared_ptr<GCancellable>(g_cancellable_new(), [](GCancellable* value) { g_object_unref(value); });
        emit changed();
        auto* future = new QFutureWatcher<QPair<QVariantMap, QString>>(this);
        connect(future, &QFutureWatcherBase::finished, this, [this, future, request] {
            const auto result = future->result();
            future->deleteLater();
            if (request != generation) {
                return;
            }
            values = result.first;
            failure = result.second;
            busy = false;
            emit changed();
        });
        const auto source = currentSource;
        const auto cancel = cancellation;
        future->setFuture(QtConcurrent::run([source, cancel] {
            QPair<QVariantMap, QString> result;
            auto* file = g_file_new_for_uri(source.toEncoded().constData());
            GError* error = nullptr;
            auto* info = g_file_query_info(file, "standard::type,standard::size,standard::content-type,time::created,time::modified,time::access,owner::user,access::can-read,access::can-write,unix::mode,metadata::pedro-tags", G_FILE_QUERY_INFO_NONE, cancel.get(), &error);
            if (info) {
                auto& data = result.first;
                data["folder"] = g_file_info_get_file_type(info) == G_FILE_TYPE_DIRECTORY;
                data["size"] = QVariant::fromValue(g_file_info_get_size(info));
                const auto* type = g_file_info_get_content_type(info);
                auto* description = type ? g_content_type_get_description(type) : nullptr;
                data["type"] = description ? QString::fromUtf8(description) : QString{};
                g_free(description);
                auto* parent = g_file_get_parent(file);
                auto* path = parent ? g_file_get_parse_name(parent) : nullptr;
                data["location"] = path ? QString::fromUtf8(path) : QString{};
                g_free(path);
                g_clear_object(&parent);
                for (const auto& pair : {QPair<const char*, const char*>{"created", G_FILE_ATTRIBUTE_TIME_CREATED}, {"modified", G_FILE_ATTRIBUTE_TIME_MODIFIED}, {"accessed", G_FILE_ATTRIBUTE_TIME_ACCESS}}) {
                    if (g_file_info_has_attribute(info, pair.second)) {
                        data[pair.first] = QDateTime::fromSecsSinceEpoch(g_file_info_get_attribute_uint64(info, pair.second));
                    }
                }
                const auto* owner = g_file_info_get_attribute_string(info, G_FILE_ATTRIBUTE_OWNER_USER);
                data["owner"] = owner ? QString::fromUtf8(owner) : QString{};
                if (g_file_info_has_attribute(info, G_FILE_ATTRIBUTE_ACCESS_CAN_READ) && g_file_info_has_attribute(info, G_FILE_ATTRIBUTE_ACCESS_CAN_WRITE)) {
                    data["readable"] = g_file_info_get_attribute_boolean(info, G_FILE_ATTRIBUTE_ACCESS_CAN_READ);
                    data["writable"] = g_file_info_get_attribute_boolean(info, G_FILE_ATTRIBUTE_ACCESS_CAN_WRITE);
                }
                data["mode"] = g_file_info_get_attribute_uint32(info, G_FILE_ATTRIBUTE_UNIX_MODE);
                QStringList tags;
                auto** stored = g_file_info_get_attribute_stringv(info, "metadata::pedro-tags");
                for (int index = 0; stored && stored[index]; ++index) {
                    tags.append(QString::fromUtf8(stored[index]));
                }
                data["tags"] = tags;
                g_object_unref(info);
            } else {
                result.second = error ? QString::fromUtf8(error->message) : QStringLiteral("File information is unavailable");
            }
            g_clear_error(&error);
            g_object_unref(file);
            return result;
        }));
    }

}
