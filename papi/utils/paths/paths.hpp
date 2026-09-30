//
// Created by Brayhan De Aza on 9/28/26.
//

#pragma once

#include <filesystem>
#include <string>

namespace Pedro::Papi::Utils::Paths {
    std::filesystem::path wallpapers();
    std::filesystem::path wallpaper(const std::string& filename);

    std::filesystem::path config();
    std::filesystem::path appearanceConfig();
}
