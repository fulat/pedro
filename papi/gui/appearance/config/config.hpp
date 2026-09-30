//
// Created by Brayhan De Aza on 9/28/26.
//

#pragma once

#include <QObject>
#include <QUrl>
#include <QtQml/qqmlregistration.h>

namespace Pedro::Papi::Appearance::Config {

    class Config final : public QObject {
            Q_OBJECT
            QML_SINGLETON
            QML_NAMED_ELEMENT(AppearanceConfig)

            Q_PROPERTY(QUrl wallpaper READ wallpaper NOTIFY wallpaperChanged)

        public:

            explicit Config(QObject* parent = nullptr);

            QUrl wallpaper() const;

        signals:
            void wallpaperChanged();

        private:

            void load();

            QUrl m_wallpaper;
    };

}