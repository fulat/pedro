#pragma once

#include <string>
#include <vector>

namespace Pedro::Papi::Bluetooth {

    struct Device {
            std::string name;
            std::string icon;
            bool connected{false};
            bool paired{false};
    };

    struct Snapshot {
            bool available{false};
            bool enabled{false};
            bool scanning{false};
            std::vector<Device> devices;
    };

    class Manager final {

        public:

            [[nodiscard]] Snapshot snapshot() const;

            bool isAvailable() const;

            void setEnabled(bool enabled) const;

            void scan() const;

            void stopScan() const;
    };

} // namespace Pedro::Papi::Bluetooth