#pragma once

#include <cstdint>
#include <filesystem>
#include <string>
#include <vector>

namespace Pedro::Papi {

    struct FileInfo {
            std::filesystem::path path;

            bool isDirectory = false;
            bool isRegularFile = false;

            std::uintmax_t size = 0;
    };

    class Filesystem {
        public:

            static void createDirectory(const std::filesystem::path& path);

            static void createFile(const std::filesystem::path& path);

            static std::string readFile(const std::filesystem::path& path);

            static void writeFile(const std::filesystem::path& path, const std::string& contents);

            static void rename(const std::filesystem::path& from, const std::filesystem::path& to);

            static bool remove(const std::filesystem::path& path);

            static std::vector<FileInfo> list(const std::filesystem::path& path);

            static FileInfo metadata(const std::filesystem::path& path);
    };

}