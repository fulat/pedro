#include "manager.hpp"

#include <gio/gdesktopappinfo.h>
#include <gio/gio.h>

#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusReply>
#include <QStringList>

#include <algorithm>
#include <cctype>
#include <filesystem>
#include <fstream>
#include <iterator>
#include <memory>
#include <optional>
#include <stdexcept>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <utility>
#include <vector>

namespace Pedro::Papi::Gui::Application {
    namespace {

        constexpr auto settingsSchema = "org.gnome.shell";
        constexpr auto favoritesKey = "favorite-apps";

        QDBusMessage callShell(const QString& method, const QList<QVariant>& arguments = {}) {

            auto message = QDBusMessage::createMethodCall("org.pedro.Applications", "/org/pedro/Applications", "org.pedro.Applications", method);
            message.setArguments(arguments);
            return QDBusConnection::sessionBus().call(message, QDBus::Block, 2000);
        }

        std::optional<std::unordered_set<std::string>> shellRunning() {

            const QDBusReply<QStringList> reply(callShell("GetRunning"));
            if (!reply.isValid()) {
                return std::nullopt;
            }
            std::unordered_set<std::string> result;
            for (const auto& id : reply.value()) {
                result.insert(id.toStdString());
            }
            return result;
        }

        // Releases GLib objects through standard C++ ownership.
        template <typename Type> struct ObjectDeleter {

                void operator()(Type* value) const {

                    if (value) {
                        g_object_unref(value);
                    }
                }
        };

        // Releases a GLib string vector through standard C++ ownership.
        struct StringVectorDeleter {

                void operator()(char** value) const {

                    g_strfreev(value);
                }
        };

        // Releases an application list and every reference stored in it.
        struct AppListDeleter {

                void operator()(GList* value) const {

                    g_list_free_full(value, g_object_unref);
                }
        };

        template <typename Type> using Object = std::unique_ptr<Type, ObjectDeleter<Type>>;
        using StringVector = std::unique_ptr<char*, StringVectorDeleter>;
        using AppList = std::unique_ptr<GList, AppListDeleter>;

        // Internal metadata needed to correlate desktop files with processes.
        struct Record {
                Info info;
                std::string executable;
                bool visible{false};
        };

        // Process names and command lines currently visible through procfs.
        struct Processes {
                std::unordered_set<std::string> executables;
                std::vector<std::string> commandLines;
        };

        std::string text(const char* value) {

            return value ? value : "";
        }

        std::string fileName(const std::string& value) {

            return std::filesystem::path(value).filename().string();
        }

        bool numeric(const std::string& value) {

            return !value.empty() && std::all_of(value.begin(), value.end(), [](unsigned char character) { return std::isdigit(character); });
        }

        bool settingsAvailable() {

            auto* source = g_settings_schema_source_get_default();

            if (!source) {
                return false;
            }

            auto* schema = g_settings_schema_source_lookup(source, settingsSchema, true);

            if (!schema) {
                return false;
            }

            g_settings_schema_unref(schema);
            return true;
        }

        Object<GSettings> settings() {

            if (!settingsAvailable()) {
                throw std::runtime_error("GNOME application favorites are unavailable");
            }

            return Object<GSettings>(g_settings_new(settingsSchema));
        }

        std::vector<std::string> favoriteIds() {

            if (!settingsAvailable()) {
                return {};
            }

            auto source = Object<GSettings>(g_settings_new(settingsSchema));
            auto values = StringVector(g_settings_get_strv(source.get(), favoritesKey));
            std::vector<std::string> result;

            if (!values) {
                return result;
            }

            for (auto index = 0U; values.get()[index]; ++index) {
                result.emplace_back(values.get()[index]);
            }

            return result;
        }

        std::string iconName(GAppInfo* application) {

            auto* icon = g_app_info_get_icon(application);

            if (!icon) {
                return {};
            }

            if (G_IS_FILE_ICON(icon)) {
                auto* file = g_file_icon_get_file(G_FILE_ICON(icon));
                auto* path = g_file_get_path(file);
                const auto result = text(path);
                g_free(path);
                return result;
            }

            if (G_IS_THEMED_ICON(icon)) {
                const auto* names = g_themed_icon_get_names(G_THEMED_ICON(icon));

                if (names && names[0]) {
                    return names[0];
                }
            }

            auto* serialized = g_icon_to_string(icon);
            const auto result = text(serialized);
            g_free(serialized);
            return result;
        }

        Record record(GAppInfo* application) {

            Record result;
            result.info.id = text(g_app_info_get_id(application));
            result.info.name = text(g_app_info_get_display_name(application));
            result.info.icon = iconName(application);
            result.executable = text(g_app_info_get_executable(application));
            result.visible = g_app_info_should_show(application);
            return result;
        }

        std::vector<Record> applications() {

            const auto list = AppList(g_app_info_get_all());
            std::unordered_map<std::string, Record> unique;

            for (auto* item = list.get(); item; item = item->next) {
                auto value = record(G_APP_INFO(item->data));

                if (!value.info.id.empty() && !value.info.name.empty()) {
                    unique.insert_or_assign(value.info.id, std::move(value));
                }
            }

            std::vector<Record> result;
            result.reserve(unique.size());

            for (auto& [id, value] : unique) {
                result.push_back(std::move(value));
            }

            std::sort(result.begin(), result.end(), [](const Record& left, const Record& right) { return left.info.name < right.info.name; });
            return result;
        }

        Processes processes() {

            Processes result;
            std::error_code error;
            const std::filesystem::directory_iterator end;

            for (std::filesystem::directory_iterator item("/proc", std::filesystem::directory_options::skip_permission_denied, error); item != end; item.increment(error)) {
                if (error) {
                    error.clear();
                    continue;
                }

                const auto processId = item->path().filename().string();

                if (!numeric(processId)) {
                    continue;
                }

                const auto executable = std::filesystem::read_symlink(item->path() / "exe", error);

                if (!error) {
                    result.executables.insert(executable.filename().string());
                }

                error.clear();
                std::ifstream stream(item->path() / "cmdline", std::ios::binary);
                std::string commandLine((std::istreambuf_iterator<char>(stream)), std::istreambuf_iterator<char>());

                if (commandLine.empty()) {
                    continue;
                }

                std::replace(commandLine.begin(), commandLine.end(), '\0', ' ');
                result.commandLines.push_back(std::move(commandLine));
            }

            return result;
        }

        bool genericExecutable(const std::string& executable) {

            static const std::unordered_set<std::string> generic = {
                "bash", "electron", "env", "flatpak", "java", "python", "python3", "sh", "snap",
            };

            return generic.find(executable) != generic.end();
        }

        // Identifies desktop entries owned by Ubuntu, GNOME, or freedesktop infrastructure.
        bool systemApplication(const Record& application) {

            static const std::vector<std::string> namespaces = {
                "com.ubuntu.",
                "io.snapcraft.",
                "org.freedesktop.",
                "org.gnome.",
            };
            static const std::unordered_set<std::string> identifiers = {
                "snap-store_snap-store.desktop",
                "ubuntu-software.desktop",
            };
            const auto& id = application.info.id;

            if (identifiers.find(id) != identifiers.end()) {
                return true;
            }

            return std::any_of(namespaces.begin(), namespaces.end(), [&id](const auto& name) { return id.rfind(name, 0) == 0; });
        }

        bool running(const Record& application, const Processes& active) {

            const auto executable = fileName(application.executable);

            if (!executable.empty() && !genericExecutable(executable) && active.executables.find(executable) != active.executables.end()) {
                return true;
            }

            auto identity = application.info.id;
            constexpr auto desktopSuffix = ".desktop";

            if (identity.size() > std::char_traits<char>::length(desktopSuffix) && identity.compare(identity.size() - std::char_traits<char>::length(desktopSuffix), std::char_traits<char>::length(desktopSuffix), desktopSuffix) == 0) {
                identity.erase(identity.size() - std::char_traits<char>::length(desktopSuffix));
            }

            for (const auto& commandLine : active.commandLines) {
                if (identity.size() > 3 && commandLine.find(identity) != std::string::npos) {
                    return true;
                }
            }

            return false;
        }

    } // namespace

    Snapshot Manager::snapshot() const {

        auto records = applications();
        const auto favorites = favoriteIds();
        const auto windows = shellRunning();
        const auto active = windows ? Processes{} : processes();
        std::unordered_map<std::string, std::size_t> indexes;
        std::unordered_set<std::string> pinned;
        Snapshot result;

        for (auto index = 0U; index < records.size(); ++index) {
            indexes.insert_or_assign(records[index].info.id, index);
            records[index].info.running = windows ? windows->count(records[index].info.id) > 0 : running(records[index], active);
        }

        for (const auto& id : favorites) {
            const auto item = indexes.find(id);

            if (item == indexes.end() || systemApplication(records[item->second])) {
                continue;
            }

            auto application = records[item->second].info;
            application.pinned = true;
            pinned.insert(application.id);
            result.pinned.push_back(std::move(application));
        }

        for (const auto& value : records) {
            if (value.visible) {
                auto application = value.info;
                application.pinned = pinned.find(application.id) != pinned.end();
                result.installed.push_back(std::move(application));
            }
        }

        return result;
    }

    void Manager::activate(const std::string& id) const {

        if (id.empty()) {
            throw std::invalid_argument("Application id cannot be empty");
        }
        const auto reply = callShell("Activate", {QString::fromStdString(id)});
        if (reply.type() == QDBusMessage::ReplyMessage) {
            return;
        }
        if (reply.errorName() != "org.freedesktop.DBus.Error.ServiceUnknown" && reply.errorName() != "org.freedesktop.DBus.Error.NameHasNoOwner") {
            throw std::runtime_error("GNOME application activation failed: " + reply.errorMessage().toStdString());
        }
        // Never launch a duplicate when GNOME activation is unavailable.
        auto application = Object<GDesktopAppInfo>(g_desktop_app_info_new(id.c_str()));
        if (!application) {
            throw std::runtime_error("Application is not installed: " + id);
        }
        if (running(record(G_APP_INFO(application.get())), processes())) {
            throw std::runtime_error("Enable Pedro Applications in GNOME and log in again to focus existing windows");
        }
        launch(id);
    }

    bool Manager::placeWindow(unsigned int pid, const std::string& title, const std::string& shellTitle) const {

        const QDBusReply<bool> reply(callShell("PlaceWindow", {pid, QString::fromStdString(title), QString::fromStdString(shellTitle)}));
        return reply.isValid() && reply.value();
    }

    bool Manager::activateWindow(unsigned int pid, const std::string& title) const {

        const QDBusReply<bool> reply(callShell("ActivateWindow", {pid, QString::fromStdString(title)}));
        return reply.isValid() && reply.value();
    }

    unsigned int Manager::placeWindowIdentity(unsigned int pid, const std::string& title, const std::string& shellTitle) const {

        const QDBusReply<unsigned int> reply(callShell("PlaceWindowIdentity", {pid, QString::fromStdString(title), QString::fromStdString(shellTitle)}));
        if (reply.isValid()) {
            return reply.value();
        }
        // Existing sessions may still run the previous GNOME extension until login.
        if (reply.error().type() == QDBusError::UnknownMethod) {
            placeWindow(pid, title, shellTitle);
        }
        return 0;
    }

    bool Manager::activateWindowIdentity(unsigned int pid, unsigned int identity) const {

        const QDBusReply<bool> reply(callShell("ActivateWindowIdentity", {pid, identity}));
        return reply.isValid() && reply.value();
    }

    void Manager::launch(const std::string& id) const {

        if (id.empty()) {
            throw std::invalid_argument("Application id cannot be empty");
        }

        auto application = Object<GDesktopAppInfo>(g_desktop_app_info_new(id.c_str()));

        if (!application) {
            throw std::runtime_error("Application is not installed: " + id);
        }

        GError* error = nullptr;

        if (!g_app_info_launch(G_APP_INFO(application.get()), nullptr, nullptr, &error)) {
            const auto message = error ? text(error->message) : "Unable to launch application";

            if (error) {
                g_error_free(error);
            }

            throw std::runtime_error(message);
        }
    }

    void Manager::setPinned(const std::string& id, bool pinned) const {

        if (id.empty()) {
            throw std::invalid_argument("Application id cannot be empty");
        }

        auto application = Object<GDesktopAppInfo>(g_desktop_app_info_new(id.c_str()));

        if (!application) {
            throw std::runtime_error("Application is not installed: " + id);
        }

        auto values = favoriteIds();
        const auto existing = std::find(values.begin(), values.end(), id);

        if (pinned && existing == values.end()) {
            values.push_back(id);
        } else if (!pinned && existing != values.end()) {
            values.erase(existing);
        } else {
            return;
        }

        std::vector<const char*> raw;
        raw.reserve(values.size() + 1);

        for (const auto& value : values) {
            raw.push_back(value.c_str());
        }

        raw.push_back(nullptr);
        auto destination = settings();

        if (!g_settings_set_strv(destination.get(), favoritesKey, raw.data())) {
            throw std::runtime_error("Unable to update GNOME application favorites");
        }

        g_settings_sync();
    }

} // namespace Pedro::Papi::Gui::Application
