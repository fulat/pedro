#pragma once

#include <cstdint>
#include <string>

namespace Pedro::Papi::Network::Wifi {

    struct Access {
            std::string name;
            std::uint8_t strength{0};
            bool secured{false};
            bool connected{false};
    };

}
