#include <gio/gio.h>

#include <pedro/papi/io/file/watch.h>

#include <QFile>
#include <QFileInfo>
#include <QPointer>
#include <QTimer>

#include <sys/stat.h>
#include <unistd.h>

namespace Pedro::Papi::Io::File {

    struct Watch::Data {
            QUrl source;
            QPointer<Watch> owner;
            QFile anchor;
            QString anchorPath;
            QString signature;
            QList<GFileMonitor*> monitors;
            QTimer debounce;
            QTimer location;
            bool available = false;

            void clearMonitors() {
                for (auto* monitor : monitors) {
                    g_signal_handlers_disconnect_by_data(monitor, this);
                    g_file_monitor_cancel(monitor);
                    g_object_unref(monitor);
                }
                monitors.clear();
            }
    };

    Watch::Watch(QObject* parent) : QObject(parent), data(std::make_unique<Data>()) {
        data->owner = this;
        data->debounce.setSingleShot(true);
        data->debounce.setInterval(80);
        connect(&data->debounce, &QTimer::timeout, this, &Watch::refresh);
        // GIO may report MOVED_OUT without a destination. The retained handle
        // resolves that destination, including moves of a containing folder.
        data->location.setInterval(500);
        connect(&data->location, &QTimer::timeout, this, &Watch::refresh);
    }

    Watch::~Watch() {
        close();
    }

    void Watch::close() {
        data->debounce.stop();
        data->location.stop();
        data->clearMonitors();
        data->anchor.close();
        data->source.clear();
        data->anchorPath.clear();
        data->signature.clear();
        data->available = false;
    }

    void Watch::open(const QUrl& source) {
        close();
        if (!source.isLocalFile()) {
            return;
        }
        data->source = source;
        data->anchor.setFileName(source.toLocalFile());
        if (!data->anchor.open(QIODevice::ReadOnly)) {
            data->anchorPath.clear();
        }
        data->anchorPath = QFileInfo(source.toLocalFile()).canonicalFilePath();
        data->available = QFileInfo(source.toLocalFile()).isFile();
        monitor();
        data->location.start();
    }

    QUrl Watch::source() const {
        return data->source;
    }

    bool Watch::available() const {
        return data->available;
    }

    void Watch::monitor() {
        data->clearMonitors();
        auto* file = g_file_new_for_uri(data->source.toEncoded().constData());
        while (file) {
            auto* parent = g_file_get_parent(file);
            if (!parent) {
                g_object_unref(file);
                break;
            }
            auto* monitor = g_file_monitor_file(file, G_FILE_MONITOR_WATCH_MOVES, nullptr, nullptr);
            if (monitor) {
                g_signal_connect(monitor, "changed", G_CALLBACK(+[](GFileMonitor*, GFile* file, GFile* other, GFileMonitorEvent event, gpointer state) {
                                     auto* data = static_cast<Data*>(state);
                                     if (other && (event == G_FILE_MONITOR_EVENT_RENAMED || event == G_FILE_MONITOR_EVENT_MOVED || event == G_FILE_MONITOR_EVENT_MOVED_OUT)) {
                                         auto* from = g_file_get_uri(file);
                                         auto* to = g_file_get_uri(other);
                                         const auto source = QUrl::fromEncoded(from);
                                         const auto destination = QUrl::fromEncoded(to);
                                         g_free(from);
                                         g_free(to);
                                         const auto owner = data->owner;
                                         QMetaObject::invokeMethod(
                                             owner,
                                             [owner, source, destination] {
                                                 if (owner)
                                                     owner->follow(source, destination);
                                             },
                                             Qt::QueuedConnection);
                                     }
                                     data->debounce.start();
                                 }),
                                 data.get());
                data->monitors.append(monitor);
            }
            g_object_unref(file);
            file = parent;
        }
    }

    void Watch::follow(const QUrl& source, const QUrl& destination) {
        const auto path = data->source.toLocalFile();
        const auto prefix = source.toLocalFile();
        if (data->source.isEmpty() || (path != prefix && !path.startsWith(prefix + '/'))) {
            return;
        }
        const auto target = QUrl::fromLocalFile(destination.toLocalFile() + path.mid(prefix.size()));
        if (!QFileInfo(target.toLocalFile()).isFile()) {
            return;
        }
        const auto original = data->source;
        const auto signature = data->signature;
        open(target);
        data->signature = signature;
        emit relocated(original, target);
    }

    void Watch::refresh() {
        if (data->source.isEmpty()) {
            return;
        }
        bool relocated = false;
        struct stat retained{};
        const bool retainedValid = data->anchor.isOpen() && fstat(data->anchor.handle(), &retained) == 0;
        if (data->anchor.isOpen()) {
            const auto descriptor = QByteArray("/proc/self/fd/") + QByteArray::number(data->anchor.handle());
            QByteArray target(4096, '\0');
            const auto count = readlink(descriptor.constData(), target.data(), target.size());
            if (count > 0 && count < target.size()) {
                target.truncate(count);
                const auto path = QFile::decodeName(target);
                const auto candidate = QUrl::fromLocalFile(path);
                // A deleted/replaced inode has no destination. Never bind an
                // editor to a replacement created at an unrelated old name.
                struct stat destination{};
                if (path != data->anchorPath && retainedValid && stat(QFile::encodeName(path).constData(), &destination) == 0 && destination.st_dev == retained.st_dev && destination.st_ino == retained.st_ino) {
                    const auto original = data->source;
                    data->source = candidate;
                    data->anchorPath = path;
                    data->available = true;
                    relocated = true;
                    monitor();
                    emit this->relocated(original, candidate);
                }
            }
        }
        const bool available = QFileInfo(data->source.toLocalFile()).isFile();
        const bool availabilityChanged = available != data->available;
        data->available = available;
        struct stat current{};
        const bool currentValid = stat(QFile::encodeName(data->source.toLocalFile()).constData(), &current) == 0;
        const auto signature = currentValid ? QStringLiteral("%1:%2:%3:%4:%5").arg(qulonglong(current.st_dev)).arg(qulonglong(current.st_ino)).arg(qlonglong(current.st_size)).arg(qlonglong(current.st_mtim.tv_sec)).arg(qlonglong(current.st_mtim.tv_nsec)) : QString{};
        const bool contentChanged = signature != data->signature;
        data->signature = signature;
        // Atomic saves replace the inode at the same logical location. Anchor
        // the replacement so a later rename still follows the saved document.
        if (available && !relocated && (!retainedValid || current.st_dev != retained.st_dev || current.st_ino != retained.st_ino)) {
            data->anchor.close();
            data->anchor.setFileName(data->source.toLocalFile());
            if (!data->anchor.open(QIODevice::ReadOnly)) {
                data->anchorPath.clear();
            }
            data->anchorPath = QFileInfo(data->source.toLocalFile()).canonicalFilePath();
            monitor();
        }
        if (availabilityChanged || contentChanged) {
            emit changed();
        }
    }

}
