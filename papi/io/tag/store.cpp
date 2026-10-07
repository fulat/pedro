#include <gio/gio.h>

#include <pedro/papi/io/tag/store.h>
#include <pedro/papi/io/tag/event.h>

#include <QDir>
#include <QFileInfo>
#include <QLibrary>
#include <QMutex>
#include <QMutexLocker>
#include <QStandardPaths>

namespace Pedro::Papi::Io::Tag {
    namespace {

        struct Store {
                QLibrary library;
                gpointer connection = nullptr;
                QString failure;
                QMutex mutex;
                gpointer (*query)(gpointer, const gchar*, GCancellable*, GError**) = nullptr;
                gboolean (*next)(gpointer, GCancellable*, GError**) = nullptr;
                const gchar* (*string)(gpointer, gint, glong*) = nullptr;
                void (*write)(gpointer, const gchar*, GCancellable*, GError**) = nullptr;

                Store() {
                    library.setFileNameAndVersion("tinysparql-3.0", 0);
                    library.setLoadHints(QLibrary::PreventUnloadHint);
                    if (!library.load()) {
                        library.setFileNameAndVersion("tracker-sparql-3.0", 0);
                        if (!library.load()) {
                            failure = "GNOME TinySPARQL/Tracker is unavailable.";
                            return;
                        }
                    }
                    const auto create = reinterpret_cast<gpointer (*)(int, GFile*, GFile*, GCancellable*, GError**)>(library.resolve("tracker_sparql_connection_new"));
                    const auto ontology = reinterpret_cast<GFile* (*)()>(library.resolve("tracker_sparql_get_ontology_nepomuk"));
                    query = reinterpret_cast<decltype(query)>(library.resolve("tracker_sparql_connection_query"));
                    next = reinterpret_cast<decltype(next)>(library.resolve("tracker_sparql_cursor_next"));
                    string = reinterpret_cast<decltype(string)>(library.resolve("tracker_sparql_cursor_get_string"));
                    write = reinterpret_cast<decltype(write)>(library.resolve("tracker_sparql_connection_update"));
                    if (!create || !ontology || !query || !next || !string || !write) {
                        failure = "GNOME tag database API is unavailable.";
                        return;
                    }
                    const auto path = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + "/pedro/tags";
                    QDir().mkpath(path);
                    auto* folder = g_file_new_for_path(path.toUtf8().constData());
                    auto* schema = ontology();
                    GError* error = nullptr;
                    connection = create(0, folder, schema, nullptr, &error);
                    if (!connection) {
                        failure = QString::fromUtf8(error ? error->message : "Cannot open GNOME tag database.");
                    }
                    g_clear_error(&error);
                    g_object_unref(folder);
                    g_object_unref(schema);
                }

                ~Store() {
                    if (connection) {
                        g_object_unref(connection);
                    }
                }
        };

        Store& store() {
            static auto* value = new Store;
            return *value;
        }

        QList<QStringList> rows(const QString& statement, int columns, QString* failure) {
            auto& database = store();
            QMutexLocker lock(&database.mutex);
            QList<QStringList> result;
            if (!database.connection) {
                if (failure) {
                    *failure = database.failure;
                }
                return result;
            }
            GError* error = nullptr;
            auto* cursor = database.query(database.connection, statement.toUtf8().constData(), nullptr, &error);
            if (cursor) {
                while (database.next(cursor, nullptr, &error)) {
                    QStringList row;
                    for (int index = 0; index < columns; ++index) {
                        row.append(QString::fromUtf8(database.string(cursor, index, nullptr)));
                    }
                    result.append(row);
                }
                g_object_unref(cursor);
            }
            if (error && failure) {
                *failure = QString::fromUtf8(error->message);
            }
            g_clear_error(&error);
            return result;
        }

        bool validTag(const QString& value) {
            return value.startsWith("urn:pedro:tag:") && !value.contains('>') && !value.contains('<') && !value.contains(' ');
        }
    }

    QString literal(const QString& value) {
        QString encoded = value;
        encoded.replace('\\', "\\\\").replace('"', "\\\"").replace('\n', "\\n").replace('\r', "\\r");
        return '"' + encoded + '"';
    }

    bool update(const QString& statement, QString* failure) {
        auto& database = store();
        QMutexLocker lock(&database.mutex);
        if (!database.connection) {
            if (failure) {
                *failure = database.failure;
            }
            return false;
        }
        GError* error = nullptr;
        database.write(database.connection, statement.toUtf8().constData(), nullptr, &error);
        const bool success = !error;
        if (error && failure) {
            *failure = QString::fromUtf8(error->message);
        }
        g_clear_error(&error);
        return success;
    }

    bool initialize() {
        QString error;
        if (!rows("SELECT ?id WHERE { <urn:pedro:catalog> nao:identifier ?id }", 1, &error).isEmpty() || !error.isEmpty()) {
            return false;
        }
        return update("INSERT DATA { <urn:pedro:catalog> a rdfs:Resource ; nao:identifier 'tags' }");
    }

    QVariantList definitions(QString* error) {
        QVariantList result;
        for (const auto& row : rows("SELECT ?tag ?name ?color WHERE { ?tag a nao:Tag ; nao:prefLabel ?name . FILTER(STRSTARTS(STR(?tag), 'urn:pedro:tag:')) OPTIONAL { ?tag nao:description ?color } } ORDER BY ?name", 3, error)) {
            result.append(QVariantMap{{"id", row[0]}, {"name", row[1]}, {"color", row[2].isEmpty() ? "#0877ff" : row[2]}});
        }
        return result;
    }

    QStringList locations(const QString& tag, QString* error) {
        QStringList result;
        if (!validTag(tag)) {
            return result;
        }
        for (const auto& row : rows("SELECT DISTINCT ?url WHERE { <" + tag + "> a nao:Tag . ?file nie:url ?url ; nao:hasTag <" + tag + "> } ORDER BY ?url", 1, error)) {
            const QUrl url(row[0]);
            if (url.isValid() && url.scheme() != "trash") {
                result.append(row[0]);
            }
        }
        return result;
    }

    QStringList allLocations() {
        QStringList result;
        for (const auto& row : rows("SELECT DISTINCT ?url WHERE { ?file nie:url ?url ; nao:hasTag ?tag . ?tag a nao:Tag . FILTER(STRSTARTS(STR(?tag), 'urn:pedro:tag:')) }", 1, nullptr)) {
            result.append(row[0]);
        }
        return result;
    }

    QStringList fileTags(const QUrl& source) {
        QStringList result;
        for (const auto& row : rows("SELECT ?tag WHERE { ?file nie:url " + literal(source.toString(QUrl::FullyEncoded)) + " ; nao:hasTag ?tag . ?tag a nao:Tag . FILTER(STRSTARTS(STR(?tag), 'urn:pedro:tag:')) }", 1, nullptr)) {
            result.append(row[0]);
        }
        return result;
    }

    bool writeMetadata(const QUrl& source, const QStringList& tags, QString* error) {
        auto* file = g_file_new_for_uri(source.toEncoded().constData());
        auto* info = g_file_info_new();
        QList<QByteArray> encoded;
        for (const auto& id : tags) {
            encoded.append(id.toUtf8());
        }
        QList<char*> pointers;
        for (auto& id : encoded) {
            pointers.append(id.data());
        }
        pointers.append(nullptr);
        g_file_info_set_attribute_stringv(info, "metadata::pedro-tags", pointers.data());
        GError* failure = nullptr;
        const bool success = g_file_set_attributes_from_info(file, info, G_FILE_QUERY_INFO_NONE, nullptr, &failure);
        if (!success && error) {
            *error = QString::fromUtf8(failure ? failure->message : "Cannot save file tags.");
        }
        g_clear_error(&failure);
        g_object_unref(info);
        g_object_unref(file);
        return success;
    }

    bool setFileTags(const QUrl& source, const QStringList& tags, QString* error) {
        const auto uri = source.toString(QUrl::FullyEncoded);
        const auto resource = "<" + uri + ">";
        QString statement = "DELETE { " + resource + " nao:hasTag ?tag } WHERE { " + resource + " nao:hasTag ?tag . FILTER(STRSTARTS(STR(?tag), 'urn:pedro:tag:')) }; INSERT DATA { " + resource + " a nfo:FileDataObject ; nie:url " + literal(uri) + " . ";
        for (const auto& tag : tags) {
            if (validTag(tag)) {
                statement += resource + " nao:hasTag <" + tag + "> . ";
            }
        }
        return update(statement + " }", error);
    }

    void relocate(const QUrl& source, const QUrl& destination) {
        if (!QFileInfo::exists(QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + "/pedro/tags")) {
            return;
        }
        const auto from = source.toString(QUrl::FullyEncoded);
        const auto to = destination.toString(QUrl::FullyEncoded);
        const auto matches = rows("SELECT DISTINCT ?url WHERE { ?file nie:url ?url ; nao:hasTag ?tag . FILTER(?url = " + literal(from) + " || STRSTARTS(?url, " + literal(from + '/') + ")) }", 1, nullptr);
        for (const auto& row : matches) {
            const QUrl old(row[0]);
            const QUrl replacement(to + row[0].mid(from.length()));
            const auto tags = fileTags(old);
            if (setFileTags(replacement, tags)) {
                setFileTags(old, {});
            }
        }
        if (!matches.isEmpty()) {
            emit Event::instance() -> changed();
        }
    }
}
