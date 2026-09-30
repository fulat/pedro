#pragma once

#include <cstdint>
#include <string>

namespace Pedro::Papi {

    struct MemoryInfo {
            std::uint64_t totalBytes = 0;
            std::uint64_t availableBytes = 0;

            std::uint64_t usedBytes() const;
            double usedPercent() const;
    };

    struct SystemInfo {
            std::string hostname;
            std::string kernel;
            std::string architecture;

            std::uint64_t uptimeSeconds = 0;

            double cpuUsagePercent = 0.0;

            MemoryInfo memory;
    };

    class System {
        public:

            static SystemInfo snapshot();

        private:

            static bool hasPreviousCpuSample_;
            static std::uint64_t previousCpuTotal_;
            static std::uint64_t previousCpuIdle_;
    };

}