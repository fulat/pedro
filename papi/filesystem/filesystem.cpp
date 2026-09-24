#include <pedro/papi/filesystem/filesystem.hpp>

#include <algorithm>
#include <fstream>
#include <iterator>
#include <stdexcept>

namespace Pedro::Papi {
    namespace {

        FileInfo makeFileInfo(const std::filesystem::directory_entry& entry) {
            FileInfo info;
            info.path = entry.path();
            info.isDirectory = entry.is_directory();
            info.isRegularFile = entry.is_regular_file();
            if (info.isRegularFile) {
                info.size = entry.file_size();
            }
            return info;
        }

    } // namespace

    void Filesystem::createDirectory(const std::filesystem::path& path) {
        std::filesystem::create_directories(path);
    }

    void Filesystem::createFile(const std::filesystem::path& path) {
        std::ofstream stream(path, std::ios::app | std::ios::binary);
        if (!stream) {
            throw std::runtime_error("Unable to create file: " + path.string());
        }
    }

    std::string Filesystem::readFile(const std::filesystem::path& path) {
        std::ifstream stream(path, std::ios::binary);
        if (!stream) {
            throw std::runtime_error("Unable to open file for reading: " + path.string());
        }
        return {std::istreambuf_iterator<char>(stream), std::istreambuf_iterator<char>()};
    }

    void Filesystem::writeFile(const std::filesystem::path& path, const std::string& contents) {
        std::ofstream stream(path, std::ios::trunc | std::ios::binary);
        if (!stream) {
            throw std::runtime_error("Unable to open file for writing: " + path.string());
        }
        stream.write(contents.data(), static_cast<std::streamsize>(contents.size()));
        if (!stream) {
            throw std::runtime_error("Unable to write file: " + path.string());
        }
    }

    void Filesystem::rename(const std::filesystem::path& from, const std::filesystem::path& to) {
        std::filesystem::rename(from, to);
    }

    bool Filesystem::remove(const std::filesystem::path& path) {
        return std::filesystem::remove(path);
    }

    std::vector<FileInfo> Filesystem::list(const std::filesystem::path& path) {
        std::vector<FileInfo> entries;
        for (const auto& entry : std::filesystem::directory_iterator(path)) {
            entries.push_back(makeFileInfo(entry));
        }
        std::sort(entries.begin(), entries.end(), [](const FileInfo& left, const FileInfo& right) { return left.path.filename() < right.path.filename(); });
        return entries;
    }

    FileInfo Filesystem::metadata(const std::filesystem::path& path) {
        return makeFileInfo(std::filesystem::directory_entry(path));
    }

} // namespace Pedro::Papi
