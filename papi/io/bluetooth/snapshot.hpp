#pragma once

#include "device.hpp"

#include <vector>

namespace Pedro::Papi::Bluetooth {

    struct Snapshot {
            bool available{false};
            bool enabled{false};
            bool scanning{false};
            std::vector<Device> devices;
    };

}
