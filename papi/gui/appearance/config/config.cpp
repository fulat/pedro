//
// Created by Brayhan De Aza on 9/28/26.
//

#include "config.hpp"
#include <any>
#include <filesystem>
#include <QString>

#include <pedro/papi/gui/wallpapers/wallpaper.hpp>

namespace Pedro::Papi::Appearance::Config {

    namespace fs = std::filesystem;

    Config::Config(QObject* parent) : QObject(parent) {
        load();
    }

    void Config::load() {

        const auto path = Pedro::Papi::Gui::Wallpaper::current();
        if (path.empty() || !fs::exists(path)) {
            return;
        }
        const auto wallpaper = QUrl::fromLocalFile(QString::fromStdString(path.string()));
        if (m_wallpaper != wallpaper) {
            m_wallpaper = wallpaper;
            emit wallpaperChanged();
        }
    }

    QUrl Config::wallpaper() const {
        return m_wallpaper;
    }
}