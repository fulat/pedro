#pragma once

#include "access.hpp"

#include <string>
#include <vector>

namespace Pedro::Papi::Network::Wifi {

    struct Snapshot {
            bool available{false};
            bool enabled{false};
            bool connected{false};
            std::string connectedName;
            std::vector<Access> accessPoints;
    };

}
