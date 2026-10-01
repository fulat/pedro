#include "wallpaper.hpp"

#include <QCoreApplication>
#include <QDir>
#include <QStandardPaths>
#include <QtGlobal>

#include <any>
#include <string>

#include <pedro/papi/utils/toml/toml.hpp>

namespace Pedro::Papi::Gui::Wallpaper {

    namespace {

        std::filesystem::path developmentDirectory() {

            const auto sourceDirectory = qEnvironmentVariable("PEDRO_QML_DIR");

            if (!sourceDirectory.isEmpty()) {
                return std::filesystem::path(sourceDirectory.toStdString()) / "assets" / "wallpapers";
            }

            return std::filesystem::path(QCoreApplication::applicationDirPath().toStdString()) / "assets" / "wallpapers";
        }

        std::filesystem::path productionDirectory() {
            const QString path = QStandardPaths::locate(QStandardPaths::GenericDataLocation, "pedro/wallpapers", QStandardPaths::LocateDirectory);

            return std::filesystem::path(path.toStdString());
        }

    }

    std::filesystem::path directory() {
        if (qEnvironmentVariableIsSet("PEDRO_DEVELOPMENT_MODE")) {
            return developmentDirectory();
        }

        return productionDirectory();
    }

    std::filesystem::path config() {
        return directory() / "config.toml";
    }

    std::filesystem::path current() {
        const auto configPath = config();

        const std::any value = Pedro::Papi::Utils::Toml::parse(configPath.string(), "wallpaper.light", "current");

        const auto filename = std::any_cast<std::string>(&value);

        if (!filename) {
            return {};
        }

        return directory() / *filename;
    }

}
