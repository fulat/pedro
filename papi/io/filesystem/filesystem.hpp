#pragma once

#include <cstdint>
#include <filesystem>
#include <string>
#include <vector>

namespace Pedro::Papi::FileSystem {
    struct FileInfo {
            std::filesystem::path path;

            bool isDirectory = false;
            bool isRegularFile = false;

            std::uintmax_t size = 0;
    };

    void createDirectory(const std::filesystem::path& path);

    void createFile(const std::filesystem::path& path);

    void writeFile(const std::filesystem::path& path, const std::string& contents);

    void rename(const std::filesystem::path& from, const std::filesystem::path& to);

    bool remove(const std::filesystem::path& path);

    std::string readFile(const std::filesystem::path& path);

    std::vector<FileInfo> list(const std::filesystem::path& path);

    FileInfo metadata(const std::filesystem::path& path);
}