#include "store.hpp"

#include <QCoreApplication>
#include <QDir>
#include <QFileInfo>
#include <QFile>
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

    QString Store::value(const QString& name, const QString& section, const QString& key) const {

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
        if (qEnvironmentVariableIsEmpty("PEDRO_QML_DIR") && !qEnvironmentVariableIsSet("PEDRO_DEVELOPMENT_MODE")) {
            for (const auto& name : {QStringLiteral("language"), QStringLiteral("wallpaper")}) {
                const auto target = QDir(user).filePath(name + ".toml");
                if (!QFileInfo::exists(target)) {
                    QFile::copy(QDir(defaults()).filePath(name + ".toml"), target);
                }
            }
        }
        for (const auto& directory : {defaults(), user}) {
            if (QFileInfo::exists(directory)) {
                watcher.addPath(directory);
            }
        }
        for (const auto& name : {QStringLiteral("language"), QStringLiteral("wallpaper")}) {
            const auto file = path(name);
            if (QFileInfo::exists(file)) {
                watcher.addPath(file);
            }
        }
    }

}
