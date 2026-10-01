#include "store.hpp"

#include <QCoreApplication>
#include <QDir>
#include <QFileInfo>
#include <QFile>
#include <QSaveFile>

#include <sstream>
#include <QStandardPaths>
#include <QDebug>

#include <toml++/toml.hpp>

namespace Pedro::Papi::Config {

    Store::Store(QObject* parent) : QObject(parent) {

        debounce.setSingleShot(true);
        debounce.setInterval(100);
        connect(&watcher, &QFileSystemWatcher::fileChanged, this, [this] { debounce.start(); });
        connect(&watcher, &QFileSystemWatcher::directoryChanged, this, [this] { debounce.start(); });
        connect(&debounce, &QTimer::timeout, this, [this] {
            watch();
            emit changed();
        });
        watch();
    }

    QString Store::defaults() {

        const auto source = qEnvironmentVariable("PEDRO_QML_DIR");
        if (!source.isEmpty()) {
            return QDir(source).filePath("config");
        }
        if (qEnvironmentVariableIsSet("PEDRO_DEVELOPMENT_MODE")) {
            return QDir(QCoreApplication::applicationDirPath()).filePath("config");
        }
        return QStandardPaths::locate(QStandardPaths::GenericDataLocation, "pedro/config", QStandardPaths::LocateDirectory);
    }

    QString Store::path(const QString& name) {

        const auto user = QDir(QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation)).filePath("pedro/" + name + ".toml");
        return QFileInfo::exists(user) ? user : QDir(defaults()).filePath(name + ".toml");
    }

    QString Store::value(const QString& name, const QString& section, const QString& key) {

        try {
            const auto table = toml::parse_file(path(name).toStdString());
            return QString::fromStdString(table.at_path((section + "." + key).toStdString()).value_or(std::string{}));
        } catch (const toml::parse_error& error) {
            qWarning() << "Pedro configuration:" << error.what();
            return {};
        }
    }

    void Store::watch() {

        if (!watcher.files().isEmpty()) {
            watcher.removePaths(watcher.files());
        }
        if (!watcher.directories().isEmpty()) {
            watcher.removePaths(watcher.directories());
        }
        const auto user = QDir(QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation)).filePath("pedro");
        QDir().mkpath(user);
        const auto preferences = QDir(user).filePath("preferences.toml");
        if (!QFileInfo::exists(preferences)) {
            // Import existing user overrides once, without removing legacy files.
            bool legacy = false;
            for (const auto& name : {QStringLiteral("language"), QStringLiteral("wallpaper"), QStringLiteral("appearance")}) {
                legacy = legacy || QFileInfo::exists(QDir(user).filePath(name + ".toml"));
            }
            if (legacy) {
                try {
                    auto table = toml::parse_file(QDir(defaults()).filePath("preferences.toml").toStdString());
                    for (const auto& name : {QStringLiteral("language"), QStringLiteral("wallpaper"), QStringLiteral("appearance")}) {
                        const auto file = QDir(user).filePath(name + ".toml");
                        if (QFileInfo::exists(file)) {
                            const auto previous = toml::parse_file(file.toStdString());
                            if (const auto* section = previous[name.toStdString()].as_table()) {
                                table.insert_or_assign(name.toStdString(), *section);
                            }
                        }
                    }
                    std::ostringstream output;
                    output << table;
                    QSaveFile file(preferences);
                    const auto contents = QByteArray::fromStdString(output.str());
                    if (!file.open(QIODevice::WriteOnly) || file.write(contents) != contents.size() || !file.commit()) {
                        qWarning() << "Could not migrate Pedro preferences:" << file.errorString();
                    }
                } catch (const toml::parse_error& error) {
                    qWarning() << "Could not migrate Pedro preferences:" << error.what();
                }
            } else if (qEnvironmentVariableIsEmpty("PEDRO_QML_DIR") && !qEnvironmentVariableIsSet("PEDRO_DEVELOPMENT_MODE")) {
                QFile::copy(QDir(defaults()).filePath("preferences.toml"), preferences);
            }
        }
        for (const auto& directory : {defaults(), user}) {
            if (QFileInfo::exists(directory)) {
                watcher.addPath(directory);
            }
        }
        for (const auto& name : {QStringLiteral("preferences")}) {
            const auto file = path(name);
            if (QFileInfo::exists(file)) {
                watcher.addPath(file);
            }
        }
    }

}
