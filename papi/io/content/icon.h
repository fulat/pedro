#ifndef PEDRO_PAPI_IO_CONTENT_ICON_H
#define PEDRO_PAPI_IO_CONTENT_ICON_H

#include <QString>
#include <QStringList>

namespace Pedro::Papi::Io::Content {

    bool isDocument(const QString& type);

    QString visualType(const QString& type);

    QStringList iconNames(const QString& type);

}

#endif
