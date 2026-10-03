#pragma once

#include <QDateTime>
#include <QString>
#include <QUrl>
#include <QVariantMap>

namespace Pedro::Gui::Appearance {

    class Palette {

        public:

            QVariantMap snapshot(const QUrl& wallpaper) const;

        private:

            mutable QString source;
            mutable QDateTime modified;
            mutable qint64 fileSize = -1;
            mutable QVariantMap colors;
    };
}
