#include <gio/gio.h>

#include <pedro/papi/io/search/provider.h>

#include <QLibrary>
#include <QSet>
#include <QUrl>

namespace Pedro::Papi::Io::Search {

    Result query(const QString& text, GCancellable* cancellation) {

        Result result;
        QLibrary library(QStringLiteral("tinysparql-3.0"), 0);
        // Registered GTypes must remain valid after the request finishes.
        library.setLoadHints(QLibrary::PreventUnloadHint);
        if (!library.load()) {
            library.setFileNameAndVersion(QStringLiteral("tracker-sparql-3.0"), 0);
            if (!library.load()) {
                result.error = QStringLiteral("GNOME search requires the TinySPARQL/Tracker runtime library.");
                return result;
            }
        }
        // TinySPARQL retains the public Tracker 3 ABI on both GNOME generations.
        const auto connect = reinterpret_cast<gpointer (*)(const gchar*, const gchar*, GDBusConnection*, GError**)>(library.resolve("tracker_sparql_connection_bus_new"));
        const auto execute = reinterpret_cast<gpointer (*)(gpointer, const gchar*, GCancellable*, GError**)>(library.resolve("tracker_sparql_connection_query"));
        const auto next = reinterpret_cast<gboolean (*)(gpointer, GCancellable*, GError**)>(library.resolve("tracker_sparql_cursor_next"));
        const auto string = reinterpret_cast<const gchar* (*)(gpointer, gint, glong*)>(library.resolve("tracker_sparql_cursor_get_string"));
        const auto escape = reinterpret_cast<gchar* (*)(const gchar*)>(library.resolve("tracker_sparql_escape_string"));
        if (!connect || !execute || !next || !string || !escape) {
            result.error = QStringLiteral("The GNOME search library does not provide the Tracker 3 API.");
            return result;
        }
        GError* error = nullptr;
        auto* connection = connect("org.freedesktop.LocalSearch3", nullptr, nullptr, &error);
        if (!connection && !g_cancellable_is_cancelled(cancellation)) {
            g_clear_error(&error);
            connection = connect("org.freedesktop.Tracker3.Miner.Files", nullptr, nullptr, &error);
        }
        if (!connection) {
            result.error = QStringLiteral("GNOME file search is unavailable: ") + QString::fromUtf8(error ? error->message : "no search service");
            g_clear_error(&error);
            return result;
        }
        QString expression = QStringLiteral("SELECT DISTINCT ?url WHERE { ?file a nfo:FileDataObject ; nie:url ?url ; nfo:fileName ?name . ");
        for (const auto& term : text.simplified().split(' ', Qt::SkipEmptyParts)) {
            auto* escaped = escape(term.toUtf8().constData());
            expression += QStringLiteral("FILTER(CONTAINS(LCASE(?name), LCASE(\"") + QString::fromUtf8(escaped) + QStringLiteral("\"))) ");
            g_free(escaped);
        }
        expression += QStringLiteral("} ORDER BY ?url");
        auto* cursor = execute(connection, expression.toUtf8().constData(), cancellation, &error);
        if (cursor) {
            while (next(cursor, cancellation, &error)) {
                const auto location = QString::fromUtf8(string(cursor, 0, nullptr));
                const QUrl url(location);
                if (url.isLocalFile()) {
                    result.locations.append(location);
                }
            }
            g_object_unref(cursor);
        }
        if (error) {
            result.error = QString::fromUtf8(error->message);
            g_clear_error(&error);
        }
        g_object_unref(connection);
        if (!result.error.isEmpty() || g_cancellable_is_cancelled(cancellation)) {
            return result;
        }
        // GNOME Files can also supply recent/bookmarked locations outside the
        // index (for example shared VM folders). Never launch its window/app.
        auto* bus = g_bus_get_sync(G_BUS_TYPE_SESSION, cancellation, nullptr);
        if (bus) {
            GVariantBuilder terms;
            g_variant_builder_init(&terms, G_VARIANT_TYPE("as"));
            for (const auto& term : text.simplified().split(' ', Qt::SkipEmptyParts)) {
                g_variant_builder_add(&terms, "s", term.toUtf8().constData());
            }
            auto* reply = g_dbus_connection_call_sync(bus, "org.gnome.Nautilus", "/org/gnome/Nautilus/SearchProvider", "org.gnome.Shell.SearchProvider2", "GetInitialResultSet", g_variant_new("(as)", &terms), G_VARIANT_TYPE("(as)"), G_DBUS_CALL_FLAGS_NO_AUTO_START, 3000, cancellation, nullptr);
            if (reply) {
                auto* locations = g_variant_get_child_value(reply, 0);
                GVariantIter iterator;
                g_variant_iter_init(&iterator, locations);
                const char* value = nullptr;
                QSet<QString> seen(result.locations.begin(), result.locations.end());
                while (g_variant_iter_next(&iterator, "&s", &value)) {
                    const auto location = QString::fromUtf8(value);
                    if (QUrl(location).isLocalFile() && !seen.contains(location)) {
                        seen.insert(location);
                        result.locations.append(location);
                    }
                }
                g_variant_unref(locations);
                g_variant_unref(reply);
            }
            g_object_unref(bus);
        }
        return result;
    }

}
