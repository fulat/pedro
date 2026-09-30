#pragma once

#include <string>

namespace Pedro::Papi::Bluetooth {

    struct Device {
            std::string name;
            std::string icon;
            bool connected{false};
            bool paired{false};
    };

}
