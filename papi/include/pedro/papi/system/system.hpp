#pragma once

#include <cstdint>
#include <optional>
#include <string>

namespace Pedro::Papi {

    struct MemoryInfo {
            std::uint64_t totalBytes{0};
            std::uint64_t availableBytes{0};

            [[nodiscard]] std::uint64_t usedBytes() const;
            [[nodiscard]] double usedPercent() const;
    };

    struct SystemInfo {
            std::string hostname;
            std::string kernel;
            std::string architecture;
            std::uint64_t uptimeSeconds{0};
            MemoryInfo memory;
            std::optional<double> cpuUsagePercent;
    };

    class System final {
        public:

            SystemInfo snapshot();

        private:

            std::uint64_t previousCpuTotal_{0};
            std::uint64_t previousCpuIdle_{0};
            bool hasPreviousCpuSample_{false};
    };

} // namespace Pedro::Papi
