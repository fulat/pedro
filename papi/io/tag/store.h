#ifndef PEDRO_PAPI_IO_TAG_STORE_H
#define PEDRO_PAPI_IO_TAG_STORE_H

#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QUrl>

namespace Pedro::Papi::Io::Tag {

    bool initialize();

    QVariantList definitions(QString* error = nullptr);

    bool update(const QString& statement, QString* error = nullptr);

    QString literal(const QString& value);

    QStringList locations(const QString& tag, QString* error = nullptr);

    QStringList allLocations();

    QStringList fileTags(const QUrl& source);

    bool writeMetadata(const QUrl& source, const QStringList& tags, QString* error = nullptr);

    bool setFileTags(const QUrl& source, const QStringList& tags, QString* error = nullptr);

    void relocate(const QUrl& source, const QUrl& destination);

}
#endif
