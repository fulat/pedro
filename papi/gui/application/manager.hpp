#pragma once

#include "snapshot.hpp"

#include <string>

namespace Pedro::Papi::Gui::Application {

    // Provides desktop application discovery and GNOME favorite management.
    class Manager final {

        public:

            [[nodiscard]] Snapshot snapshot() const;

            void launch(const std::string& id) const;

            void setPinned(const std::string& id, bool pinned) const;
    };

} // namespace Pedro::Papi::Gui::Application
