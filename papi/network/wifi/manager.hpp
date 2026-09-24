#pragma once

#include "snapshot.hpp"

namespace Pedro::Papi::Network::Wifi {

    class Manager final {

        public:

            [[nodiscard]] Snapshot snapshot() const;

            void setEnabled(bool enabled) const;

            void scan() const;
    };

}
