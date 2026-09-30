//
// Created by Brayhan De Aza on 9/28/26.
//

#pragma once
#include <any>
#include <string>

namespace Pedro::Papi::Utils::Toml {
    std::any parse(const std::string& path, const std::string& section, const std::string& key);
}