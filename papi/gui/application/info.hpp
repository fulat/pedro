#pragma once

#include <string>

namespace Pedro::Papi::Gui::Application {

    // Describes one desktop application exposed to Pedro consumers.
    struct Info {
            std::string id;
            std::string name;
            std::string icon;
            bool pinned{false};
            bool running{false};
    };

} // namespace Pedro::Papi::Gui::Application
