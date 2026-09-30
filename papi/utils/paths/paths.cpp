//
// Created by Brayhan De Aza on 9/28/26.
//

#include "paths.hpp"
#include <QStandardPaths>

namespace Pedro::Papi::Utils::Paths {

    namespace fs = std::filesystem;

    fs::path wallpapers() {
        const QString path = QStandardPaths::locate(QStandardPaths::GenericDataLocation, "pedro/wallpapers", QStandardPaths::LocateDirectory);

        return fs::path(path.toStdString());
    }

    fs::path wallpaper(const std::string& filename) {
        return wallpapers() / filename;
    }

    fs::path config() {
        const QString path = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation);

        return fs::path(path.toStdString()) / "pedro";
    }

    fs::path appearanceConfig() {
        return config() / "appearance.toml";
    }

}