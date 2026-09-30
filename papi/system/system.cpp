#include "system.hpp"

#include <sys/utsname.h>
#include <unistd.h>

#include <algorithm>
#include <array>
#include <cstdint>
#include <fstream>
#include <sstream>
#include <stdexcept>
#include <string>
#include <utility>

namespace Pedro::Papi {

    namespace {

        constexpr std::uint64_t kibibyte = 1024;

        std::pair<std::uint64_t, std::uint64_t> readCpuCounters() {
            std::ifstream stream("/proc/stat");

            std::string label;
            std::array<std::uint64_t, 10> fields{};

            if (!(stream >> label) || label != "cpu") {
                throw std::runtime_error("Unable to read aggregate CPU data from /proc/stat");
            }

            for (auto& field : fields) {
                if (!(stream >> field)) {
                    break;
                }
            }

            // guest and guest_nice are already included in user and nice by Linux.
            std::uint64_t total = 0;

            for (std::size_t index = 0; index < 8; ++index) {
                total += fields[index];
            }

            return {total, fields[3] + fields[4]};
        }

        MemoryInfo readMemory() {
            std::ifstream stream("/proc/meminfo");

            if (!stream) {
                throw std::runtime_error("Unable to read /proc/meminfo");
            }

            MemoryInfo memory;

            std::uint64_t free = 0;
            std::uint64_t buffers = 0;
            std::uint64_t cached = 0;

            std::string line;

            while (std::getline(stream, line)) {
                std::istringstream fields(line);

                std::string key;
                std::uint64_t value = 0;

                if (!(fields >> key >> value)) {
                    continue;
                }

                const auto bytes = value * kibibyte;

                if (key == "MemTotal:") {
                    memory.totalBytes = bytes;
                } else if (key == "MemAvailable:") {
                    memory.availableBytes = bytes;
                } else if (key == "MemFree:") {
                    free = bytes;
                } else if (key == "Buffers:") {
                    buffers = bytes;
                } else if (key == "Cached:") {
                    cached = bytes;
                }
            }

            if (memory.totalBytes == 0) {
                throw std::runtime_error("/proc/meminfo did not contain MemTotal");
            }

            if (memory.availableBytes == 0) {
                memory.availableBytes = free + buffers + cached;
            }

            return memory;
        }

        std::uint64_t readUptime() {
            std::ifstream stream("/proc/uptime");

            double seconds = 0;

            if (!(stream >> seconds)) {
                throw std::runtime_error("Unable to read /proc/uptime");
            }

            return static_cast<std::uint64_t>(seconds);
        }

        std::string readHostname() {
            std::array<char, 256> buffer{};

            if (::gethostname(buffer.data(), buffer.size() - 1) != 0) {
                throw std::runtime_error("Unable to read the system hostname");
            }

            return buffer.data();
        }

    }

    bool System::hasPreviousCpuSample_ = false;
    std::uint64_t System::previousCpuTotal_ = 0;
    std::uint64_t System::previousCpuIdle_ = 0;

    std::uint64_t MemoryInfo::usedBytes() const {
        return totalBytes > availableBytes ? totalBytes - availableBytes : 0;
    }

    double MemoryInfo::usedPercent() const {
        if (totalBytes == 0) {
            return 0.0;
        }

        return 100.0 * static_cast<double>(usedBytes()) / static_cast<double>(totalBytes);
    }

    SystemInfo System::snapshot() {
        SystemInfo info;

        info.hostname = readHostname();
        info.uptimeSeconds = readUptime();
        info.memory = readMemory();

        utsname identity{};

        if (::uname(&identity) == 0) {
            info.kernel = std::string(identity.sysname) + " " + identity.release;

            info.architecture = identity.machine;
        }

        const auto [total, idle] = readCpuCounters();

        if (hasPreviousCpuSample_ && total > previousCpuTotal_) {
            const auto totalDelta = total - previousCpuTotal_;

            const auto idleDelta = idle >= previousCpuIdle_ ? idle - previousCpuIdle_ : 0;

            info.cpuUsagePercent = std::clamp(100.0 * static_cast<double>(totalDelta - std::min(totalDelta, idleDelta)) / static_cast<double>(totalDelta), 0.0, 100.0);
        }

        previousCpuTotal_ = total;
        previousCpuIdle_ = idle;
        hasPreviousCpuSample_ = true;

        return info;
    }

}