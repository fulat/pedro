#pragma once

#include <QImage>
#include <QUrl>

namespace Pedro::Papi::Io::Thumbnail {

    // Runs blocking native thumbnail work; callers must use a worker thread.
    QImage image(const QUrl& source);

}
