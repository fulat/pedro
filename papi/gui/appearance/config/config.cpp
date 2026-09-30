//
// Created by Brayhan De Aza on 9/28/26.
//

#include "config.hpp"
#include <any>
#include <filesystem>
#include <QString>

#include <pedro/papi/utils/paths/paths.hpp>
#include <pedro/papi/utils/toml/toml.hpp>

namespace Pedro::Papi::Appearance::Config {

    namespace fs = std::filesystem;

    Config::Config(QObject* parent) : QObject(parent) {
        load();
    }

    void Config::load() {
        const fs::path configPath = Utils::Paths::appearanceConfig();

        auto value = Utils::Toml::parse(configPath.string(), "wallpaper", "current");

        auto filename = std::any_cast<std::string>(&value);

        if (!filename)
            return;

        const fs::path path = Utils::Paths::wallpaper(*filename);

        if (!fs::exists(path))
            return;

        m_wallpaper = QUrl::fromLocalFile(QString::fromStdString(path.string()));
    }

    QUrl Config::wallpaper() const {
        return m_wallpaper;
    }
}