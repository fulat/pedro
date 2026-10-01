#pragma once

#include <filesystem>
#include <QString>

namespace Pedro::Papi::Gui::Wallpaper {
    std::filesystem::path directory();
    std::filesystem::path config();
    std::filesystem::path current(const QString& mode = {});
}