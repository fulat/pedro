#include <gio/gdesktopappinfo.h>
#include <gio/gio.h>

#include <pedro/papi/io/content/applications.hpp>

#include <QByteArray>
#include <QFutureWatcher>
#include <QPointer>
#include <QVariantMap>
#include <QtConcurrent>

#include <algorithm>

namespace Pedro::Papi::Io::Content {

    namespace {

        struct Result {
                QVariantList applications;
                QString error;
        };

        struct Launch {
                QPointer<Applications> target;
                QByteArray uri;
                GList urls;

                Launch(Applications* model, const QUrl& source) : target(model), uri(source.toEncoded()), urls{uri.data(), nullptr, nullptr} {
                }
        };

        Result discover(const QUrl& source, GCancellable* cancel) {

            Result result;
            auto* file = g_file_new_for_uri(source.toEncoded().constData());
            GError* error = nullptr;
            auto* info = g_file_query_info(file, "standard::content-type,standard::type", G_FILE_QUERY_INFO_NONE, cancel, &error);
            g_object_unref(file);

            if (!info) {
                result.error = error ? QString::fromUtf8(error->message) : QStringLiteral("Cannot read file type");
                g_clear_error(&error);
                return result;
            }

            const auto* type = g_file_info_get_content_type(info);
            auto* preferred = type ? g_app_info_get_default_for_type(type, !source.isLocalFile()) : nullptr;
            auto* apps = type ? g_app_info_get_all_for_type(type) : nullptr;
            for (auto* node = apps; node; node = node->next) {
                auto* app = G_APP_INFO(node->data);
                const auto* id = g_app_info_get_id(app);
                if (!id || !g_app_info_should_show(app) || (!g_app_info_supports_uris(app) && (!source.isLocalFile() || !g_app_info_supports_files(app)))) {
                    continue;
                }

                QString icon;
                auto* appIcon = g_app_info_get_icon(app);
                if (appIcon && G_IS_THEMED_ICON(appIcon)) {
                    const auto* names = g_themed_icon_get_names(G_THEMED_ICON(appIcon));
                    if (names && names[0]) {
                        icon = QString::fromUtf8(names[0]);
                    }
                } else if (appIcon && G_IS_FILE_ICON(appIcon)) {
                    auto* path = g_file_get_path(g_file_icon_get_file(G_FILE_ICON(appIcon)));
                    icon = QString::fromUtf8(path ? path : "");
                    g_free(path);
                }

                result.applications.append(QVariantMap{{"id", QString::fromUtf8(id)}, {"name", QString::fromUtf8(g_app_info_get_display_name(app))}, {"icon", icon}, {"isDefault", preferred && g_app_info_equal(app, preferred)}});
            }
            std::stable_sort(result.applications.begin(), result.applications.end(), [](const auto& left, const auto& right) {
                const auto a = left.toMap();
                const auto b = right.toMap();
                if (a.value("isDefault") != b.value("isDefault")) {
                    return a.value("isDefault").toBool();
                }
                return QString::localeAwareCompare(a.value("name").toString(), b.value("name").toString()) < 0;
            });
            g_list_free_full(apps, g_object_unref);
            g_clear_object(&preferred);
            g_object_unref(info);
            return result;
        }

    }

    struct Applications::State {
            QUrl source;
            QVariantList applications;
            QString error;
            bool loading = false;
            bool launching = false;
            quint64 generation = 0;
            std::shared_ptr<GCancellable> cancel;
    };

    Applications::Applications(QObject* parent) : QObject(parent), state(std::make_unique<State>()) {
    }

    Applications::~Applications() {
        if (state->cancel) {
            g_cancellable_cancel(state->cancel.get());
        }
    }

    QUrl Applications::source() const {
        return state->source;
    }

    void Applications::setSource(const QUrl& source) {
        if (source != state->source) {
            state->source = source;
            refresh();
        }
    }

    QVariantList Applications::applications() const {
        return state->applications;
    }

    bool Applications::loading() const {
        return state->loading || state->launching;
    }

    QString Applications::error() const {
        return state->error;
    }

    void Applications::refresh() {

        if (state->cancel) {
            g_cancellable_cancel(state->cancel.get());
        }
        const auto generation = ++state->generation;
        state->applications.clear();
        state->error.clear();
        state->loading = !state->source.isEmpty();
        emit changed();
        if (!state->loading) {
            return;
        }

        state->cancel = std::shared_ptr<GCancellable>(g_cancellable_new(), g_object_unref);
        auto* watcher = new QFutureWatcher<Result>(this);
        connect(watcher, &QFutureWatcher<Result>::finished, this, [this, watcher, generation] {
            const auto result = watcher->result();
            watcher->deleteLater();
            if (generation != state->generation) {
                return;
            }
            state->applications = result.applications;
            state->error = result.error;
            state->loading = false;
            emit changed();
        });
        watcher->setFuture(QtConcurrent::run([source = state->source, cancel = state->cancel] { return discover(source, cancel.get()); }));
    }

    bool Applications::launch(const QString& id) {

        if (loading() || state->source.isEmpty() || std::none_of(state->applications.cbegin(), state->applications.cend(), [&id](const auto& value) { return value.toMap().value("id").toString() == id; })) {
            return false;
        }
        auto* app = g_desktop_app_info_new(id.toUtf8().constData());
        if (!app) {
            state->error = QStringLiteral("The application is no longer installed");
            emit changed();
            emit failed(state->error);
            return false;
        }

        state->launching = true;
        state->error.clear();
        emit changed();
        auto* request = new Launch(this, state->source);
        g_app_info_launch_uris_async(
            G_APP_INFO(app), &request->urls, nullptr, nullptr,
            [](GObject* source, GAsyncResult* result, gpointer data) {
                std::unique_ptr<Launch> request(static_cast<Launch*>(data));
                GError* error = nullptr;
                const bool success = g_app_info_launch_uris_finish(G_APP_INFO(source), result, &error);
                if (request->target) {
                    auto* model = request->target.data();
                    model->state->launching = false;
                    model->state->error = error ? QString::fromUtf8(error->message) : QString{};
                    emit model->changed();
                    if (success) {
                        emit model->launched();
                    } else {
                        emit model->failed(model->state->error);
                    }
                }
                g_clear_error(&error);
            },
            request);
        g_object_unref(app);
        return true;
    }

}
