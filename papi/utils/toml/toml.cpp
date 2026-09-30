//
// Created by Brayhan De Aza on 9/28/26.
//

#include "toml.hpp"

#include <cstdint>
#include <iostream>
#include <string>
#include <toml++/toml.hpp>

namespace Pedro::Papi::Utils::Toml {

    std::any parse(const std::string& path, const std::string& section, const std::string& key) {
        try {
            auto config = toml::parse_file(path);

            const std::string fullPath = section + "." + key;

            auto node = config.at_path(fullPath);

            std::cout << "\nTOML path: " << fullPath << std::endl;

            if (auto value = node.value<std::string>()) {
                std::cout << "TOML value: " << *value << std::endl;

                return *value;
            }

            if (auto value = node.value<std::int64_t>()) {
                return *value;
            }

            if (auto value = node.value<double>()) {
                return *value;
            }

            if (auto value = node.value<bool>()) {
                return *value;
            }

            std::cout << "TOML value not found" << std::endl;

            return {};
        } catch (const toml::parse_error& error) {
            std::cerr << "TOML parse error: " << error.description() << std::endl;

            return {};
        }
    }

}