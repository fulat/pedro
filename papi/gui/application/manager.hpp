#pragma once

#include "snapshot.hpp"

#include <string>

namespace Pedro::Papi::Gui::Application {

    // Provides desktop application discovery and GNOME favorite management.
    class Manager final {

        public:

            [[nodiscard]] Snapshot snapshot() const;

            void launch(const std::string& id) const;

            void activate(const std::string& id) const;

            bool placeWindow(unsigned int pid, const std::string& title, const std::string& shellTitle) const;

            bool activateWindow(unsigned int pid, const std::string& title) const;

            void setPinned(const std::string& id, bool pinned) const;
    };

} // namespace Pedro::Papi::Gui::Application
