#include <gio/gio.h>

#include <pedro/papi/io/tag/model.h>
#include <pedro/papi/io/tag/store.h>
#include <pedro/papi/io/tag/event.h>
#include <pedro/papi/io/file/watch.h>

#include <QColor>
#include <QCoreApplication>
#include <QFutureWatcher>
#include <QUuid>
#include <QtConcurrentRun>

namespace Pedro::Papi::Io::Tag {

    Model::Model(QObject* parent) : QAbstractListModel(parent) {
        connect(Event::instance(), &Event::changed, this, &Model::refresh);
        refresh();
        if (failure.isEmpty() && values.isEmpty() && initialize()) {
            const QStringList names{"work", "design", "important", "personal"};
            const QStringList colors{"#13c639", "#8e22ff", "#ffa100", "#ff6eaa"};
            const QStringList fallback{"Work", "Design", "Important", "Personal"};
            for (int index = 0; index < names.size(); ++index) {
                const auto key = "files.sample." + names[index];
                const auto translated = QCoreApplication::translate("Pedro", key.toUtf8().constData());
                create(translated == key ? fallback[index] : translated, colors[index]);
            }
        }
    }

    int Model::rowCount(const QModelIndex& parent) const {
        return parent.isValid() ? 0 : values.size();
    }
    QVariant Model::data(const QModelIndex& index, int role) const {
        if (!index.isValid() || index.row() < 0 || index.row() >= values.size()) {
            return {};
        }
        const auto value = values[index.row()].toMap();
        return role == Qt::UserRole + 1 ? value["id"] : role == Qt::UserRole + 2 ? value["name"] : role == Qt::UserRole + 3 ? value["color"] : QVariant{};
    }
    QHash<int, QByteArray> Model::roleNames() const {
        return {{Qt::UserRole + 1, "tagId"}, {Qt::UserRole + 2, "tagName"}, {Qt::UserRole + 3, "tagColor"}};
    }
    QVariantList Model::tags() const {
        return values;
    }
    QString Model::error() const {
        return failure;
    }
    bool Model::busy() const {
        return !pending.isEmpty();
    }
    int Model::revision() const {
        return version;
    }

    void Model::refresh() {
        QString error;
        const auto next = definitions(&error);
        failure = error;
        QSet<QString> ids;
        for (const auto& item : next) {
            ids.insert(item.toMap()["id"].toString());
        }
        for (int row = values.size() - 1; row >= 0; --row) {
            if (!ids.contains(values[row].toMap()["id"].toString())) {
                beginRemoveRows({}, row, row);
                values.removeAt(row);
                endRemoveRows();
            }
        }
        for (const auto& item : next) {
            int found = -1;
            for (int row = 0; row < values.size(); ++row) {
                if (values[row].toMap()["id"] == item.toMap()["id"]) {
                    found = row;
                    break;
                }
            }
            if (found < 0) {
                const int row = values.size();
                beginInsertRows({}, row, row);
                values.append(item);
                endInsertRows();
            } else if (values[found] != item) {
                values[found] = item;
                emit dataChanged(index(found), index(found));
            }
        }
        const auto locations = allLocations();
        const auto watched = monitors.keys();
        for (const auto& location : watched) {
            if (!locations.contains(location)) {
                monitors.take(location)->deleteLater();
            }
        }
        for (const auto& location : locations) {
            if (monitors.contains(location)) {
                continue;
            }
            auto* watch = new Pedro::Papi::Io::File::Watch(this);
            monitors.insert(location, watch);
            connect(watch, &Pedro::Papi::Io::File::Watch::relocated, this, [](const QUrl& source, const QUrl& destination) { relocate(source, destination); }, Qt::QueuedConnection);
            connect(watch, &Pedro::Papi::Io::File::Watch::changed, this, [] { emit Event::instance() -> changed(); }, Qt::QueuedConnection);
            watch->open(QUrl(location));
        }
        ++version;
        emit changed();
    }

    bool Model::validName(const QString& name, const QString& except) {
        const auto label = name.trimmed();
        if (label.isEmpty() || label.size() > 80 || label.contains(QChar::Null) || label.contains('\n') || label.contains('\r')) {
            failure = QCoreApplication::translate("Pedro", "tags.invalidName");
            emit changed();
            return false;
        }
        for (const auto& item : values) {
            const auto tag = item.toMap();
            if (tag["id"].toString() != except && tag["name"].toString().compare(label, Qt::CaseInsensitive) == 0) {
                failure = QCoreApplication::translate("Pedro", "tags.duplicateName");
                emit changed();
                return false;
            }
        }
        return true;
    }

    QString Model::create(const QString& name, const QString& color) {
        if (!validName(name) || !QColor(color).isValid()) {
            return {};
        }
        const auto id = "urn:pedro:tag:" + QUuid::createUuid().toString(QUuid::WithoutBraces);
        if (!update("INSERT DATA { <" + id + "> a nao:Tag ; nao:prefLabel " + literal(name.trimmed()) + " ; nao:description " + literal(QColor(color).name()) + " }", &failure)) {
            emit changed();
            return {};
        }
        emit Event::instance() -> changed();
        return id;
    }

    QVariantMap Model::definition(const QString& id) const {
        for (const auto& item : values) {
            if (item.toMap()["id"] == id) {
                return item.toMap();
            }
        }
        return {};
    }

    bool Model::rename(const QString& id, const QString& name) {
        if (definition(id).isEmpty() || !validName(name, id)) {
            return false;
        }
        if (!update("DELETE { <" + id + "> nao:prefLabel ?old } INSERT { <" + id + "> nao:prefLabel " + literal(name.trimmed()) + " } WHERE { <" + id + "> nao:prefLabel ?old }", &failure)) {
            emit changed();
            return false;
        }
        emit Event::instance() -> changed();
        return true;
    }

    bool Model::setColor(const QString& id, const QString& color) {
        if (definition(id).isEmpty() || !QColor(color).isValid()) {
            return false;
        }
        if (!update("DELETE { <" + id + "> nao:description ?old } INSERT { <" + id + "> nao:description " + literal(QColor(color).name()) + " } WHERE { <" + id + "> nao:description ?old }", &failure)) {
            emit changed();
            return false;
        }
        emit Event::instance() -> changed();
        return true;
    }

    bool Model::remove(const QString& id) {
        if (definition(id).isEmpty() || busy()) {
            return false;
        }
        QList<QPair<QUrl, QStringList>> cleanup;
        for (const auto& location : locations(id)) {
            const QUrl source(location);
            auto ids = Tag::fileTags(source);
            ids.removeAll(id);
            cleanup.append({source, ids});
        }
        if (!update("DELETE { ?file nao:hasTag <" + id + "> } WHERE { ?file nao:hasTag <" + id + "> }; DELETE DATA { <" + id + "> a rdfs:Resource }", &failure)) {
            emit changed();
            return false;
        }
        const auto operation = "remove:" + id;
        if (!cleanup.isEmpty()) {
            pending.insert(operation);
        }
        emit Event::instance() -> changed();
        if (cleanup.isEmpty()) {
            return true;
        }
        auto* future = new QFutureWatcher<QString>(this);
        connect(future, &QFutureWatcherBase::finished, this, [this, future, operation, cleanup] {
            failure = future->result();
            future->deleteLater();
            pending.remove(operation);
            emit changed();
            for (const auto& pair : cleanup) {
                emit fileTagsChanged(pair.first);
            }
        });
        future->setFuture(QtConcurrent::run([cleanup] {
            QString error;
            for (const auto& pair : cleanup) {
                writeMetadata(pair.first, pair.second, &error);
            }
            return error;
        }));
        return true;
    }

    QStringList Model::fileTags(const QUrl& source) const {
        return Tag::fileTags(source);
    }

    void Model::assign(const QUrl& source, const QString& id, bool enabled) {
        const auto uri = source.toString(QUrl::FullyEncoded);
        if (source.isEmpty() || !source.isValid() || definition(id).isEmpty() || pending.contains(uri)) {
            return;
        }
        auto ids = Tag::fileTags(source);
        const auto previous = ids;
        if (enabled && !ids.contains(id)) {
            ids.append(id);
        }
        if (!enabled) {
            ids.removeAll(id);
        }
        pending.insert(uri);
        failure.clear();
        emit changed();
        auto* future = new QFutureWatcher<QString>(this);
        connect(future, &QFutureWatcherBase::finished, this, [this, future, source, uri] {
            const auto error = future->result();
            future->deleteLater();
            pending.remove(uri);
            emit Event::instance() -> changed();
            failure = error;
            emit changed();
            emit fileTagsChanged(source);
        });
        future->setFuture(QtConcurrent::run([source, ids, previous] {
            QString error;
            if (writeMetadata(source, ids, &error) && !setFileTags(source, ids, &error)) {
                writeMetadata(source, previous);
            }
            return error;
        }));
    }
}
