#pragma once

#include "snapshot.hpp"

namespace Pedro::Papi::Bluetooth {

    class Manager final {

        public:

            [[nodiscard]] Snapshot snapshot() const;

            void setEnabled(bool enabled) const;

            void scan() const;

            void stopScan() const;
    };

}
