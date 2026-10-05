#pragma once

#include <QString>
#include <QStringList>

struct _GCancellable;

namespace Pedro::Papi::Io::Search {

    struct Result {
            QStringList locations;
            QString error;
    };

    // Queries GNOME's existing index; never crawls the filesystem.
    Result query(const QString& text, _GCancellable* cancellation);

}
