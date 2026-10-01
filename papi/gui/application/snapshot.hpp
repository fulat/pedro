#pragma once

#include "info.hpp"

#include <vector>

namespace Pedro::Papi::Gui::Application {

    // Captures installed applications and third-party GNOME favorites.
    struct Snapshot {
            std::vector<Info> installed;
            std::vector<Info> pinned;
    };

} // namespace Pedro::Papi::Gui::Application
