#pragma once

#include <filesystem>

namespace Pedro::Papi::Gui::Wallpaper {
    std::filesystem::path directory();
    std::filesystem::path config();
    std::filesystem::path current();
}