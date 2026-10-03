#include "backend.hpp"

#include <pedro/papi/io/filesystem/filesystem.hpp>
#include <pedro/papi/utils/utils.hpp>
#include <pedro/papi/gui/wallpapers/wallpaper.hpp>

#include <QDir>
#include <QFutureWatcher>
#include <QStandardPaths>
#include <QVariantMap>
#include <QtConcurrentRun>
#include <QFileInfo>
#include <QCoreApplication>
#include <QDebug>

#include <cstdlib>
#include <cmath>
#include <exception>
#include <optional>
#include <utility>
#include <iostream>
#include <string>
#include <vector>

namespace {

    template <typename Snapshot> struct Refresh {
            std::optional<Snapshot> snapshot;
            QString error;
    };

    template <typename Manager> auto readSnapshot() {

        using Result = Refresh<decltype(Manager{}.snapshot())>;
        Result result;

        try {
            result.snapshot = Manager{}.snapshot();
        } catch (const std::exception& error) {
            result.error = QString::fromUtf8(error.what());
        }

        return result;
    }

    QString formatBytes(std::uint64_t bytes) {
        constexpr double gibibyte = 1024.0 * 1024.0 * 1024.0;
        return QString::number(static_cast<double>(bytes) / gibibyte, 'f', 1) + " GiB";
    }

    QString formatUptime(std::uint64_t totalSeconds) {
        const auto days = totalSeconds / 86400;
        const auto hours = (totalSeconds % 86400) / 3600;
        const auto minutes = (totalSeconds % 3600) / 60;
        if (days > 0) {
            return QStringLiteral("%1 d %2 h %3 min").arg(days).arg(hours).arg(minutes);
        }
        return QStringLiteral("%1 h %2 min").arg(hours).arg(minutes);
    }

    QVariantMap applicationValue(const Pedro::Papi::Gui::Application::Info& application) {

        QVariantMap value;
        value.insert(QStringLiteral("id"), QString::fromStdString(application.id));
        value.insert(QStringLiteral("name"), QString::fromStdString(application.name));
        value.insert(QStringLiteral("icon"), QString::fromStdString(application.icon));
        value.insert(QStringLiteral("pinned"), application.pinned);
        value.insert(QStringLiteral("running"), application.running);
        return value;
    }

    QVariantList applicationValues(const std::vector<Pedro::Papi::Gui::Application::Info>& applications) {

        QVariantList values;
        values.reserve(static_cast<qsizetype>(applications.size()));

        for (const auto& application : applications) {
            values.push_back(applicationValue(application));
        }

        return values;
    }

} // namespace

QObject* Backend::networkConnection() {
    return &connection_;
}

QObject* Backend::battery() {
    return &battery_;
}

QObject* Backend::audioVolume() {
    return &volume_;
}

QObject* Backend::screenBrightness() {
    return &brightness_;
}

Backend::Backend(QObject* parent) : QObject(parent) {
    auto documents = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    if (documents.isEmpty() || !QDir(documents).exists()) {
        documents = QDir::homePath();
    }

    documentPath_ = QDir(documents).filePath(QStringLiteral("pedro-notes.txt"));

    connect(&refreshTimer_, &QTimer::timeout, this, &Backend::refreshSystem);
    refreshTimer_.start(1000);

    connect(&applicationsRefreshTimer_, &QTimer::timeout, this, &Backend::refreshApplications);
    applicationsRefreshTimer_.start(3000);

    connect(&wifiRefreshTimer_, &QTimer::timeout, this, &Backend::refreshWifi);
    wifiRefreshTimer_.start(10000);

    connect(&bluetoothRefreshTimer_, &QTimer::timeout, this, &Backend::refreshBluetooth);
    bluetoothRefreshTimer_.start(5000);

    const auto reloadConfiguration = [this] {
        const auto hoverScale = configuration_.number("preferences", "dock", "hoverScale");
        if (hoverScale && std::isfinite(*hoverScale) && *hoverScale >= 1.0 && *hoverScale <= 1.3 && dockHoverScale_ != *hoverScale) {
            dockHoverScale_ = *hoverScale;
            emit dockHoverScaleChanged();
        }
        const auto mode = configuration_.value("preferences", "appearance", "mode");
        if ((mode == "light" || mode == "dark") && appearanceMode_ != mode) {
            appearanceMode_ = mode;
            emit appearanceModeChanged();
        }
        const auto current = Pedro::Papi::Gui::Wallpaper::current(appearanceMode_);
        if (!current.empty() && QFileInfo::exists(QString::fromStdString(current.string()))) {
            const auto url = QUrl::fromLocalFile(QString::fromStdString(current.string()));
            if (wallpaper_ != url) {
                wallpaper_ = url;
                emit wallpaperChanged();
            }
        }
        const auto locale = configuration_.value("preferences", "language", "current");
        if ((locale == "en" || locale == "es") && language_ != locale) {
            language_ = locale;
            emit languageChanged();
        }
    };
    language_ = "es";
    connect(&configuration_, &Pedro::Papi::Config::Store::changed, this, reloadConfiguration);
    reloadConfiguration();

    refreshSystem();
    refreshApplications();
    refreshWifi();
    refreshBluetooth();
}

bool Backend::developmentMode() const {
    return std::getenv("PEDRO_DEVELOPMENT_MODE") != nullptr;
}

QUrl Backend::wallpaper() const {
    return wallpaper_;
}

QString Backend::hostname() const {
    return hostname_;
}

QString Backend::kernel() const {
    return kernel_;
}

QString Backend::architecture() const {
    return architecture_;
}

QString Backend::uptime() const {
    return uptime_;
}

double Backend::cpuUsage() const {
    return cpuUsage_;
}

double Backend::memoryUsage() const {
    return memoryUsage_;
}

QString Backend::memorySummary() const {
    return memorySummary_;
}
QString Backend::documentPath() const {
    return documentPath_;
}
QString Backend::documentText() const {
    return documentText_;
}
QString Backend::statusMessage() const {
    return statusMessage_;
}
QVariantList Backend::installedApplications() const {
    return installedApplications_;
}
QVariantList Backend::pinnedApplications() const {
    return pinnedApplications_;
}
QString Backend::applicationError() const {
    return applicationError_;
}
bool Backend::wifiAvailable() const {
    return wifiAvailable_;
}
bool Backend::wifiEnabled() const {
    return wifiEnabled_;
}
bool Backend::wifiConnected() const {
    return wifiConnected_;
}
QString Backend::connectedWifiName() const {
    return connectedWifiName_;
}
bool Backend::wifiScanning() const {
    return wifiScanning_;
}
QString Backend::wifiError() const {
    return wifiError_;
}
QVariantList Backend::wifiNetworks() const {
    return wifiNetworks_;
}

bool Backend::bluetoothAvailable() const {
    return bluetoothAvailable_;
}

bool Backend::bluetoothEnabled() const {
    return bluetoothEnabled_;
}
bool Backend::bluetoothScanning() const {
    return bluetoothScanning_;
}

QString Backend::bluetoothError() const {
    return bluetoothError_;
}
QVariantList Backend::bluetoothDevices() const {
    return bluetoothDevices_;
}

void Backend::setDocumentPath(const QString& path) {
    if (documentPath_ == path) {
        return;
    }
    documentPath_ = path;
    emit documentPathChanged();
}

void Backend::refreshSystem() {
    try {
        const auto info = system_.snapshot();

        hostname_ = QString::fromStdString(info.hostname);
        kernel_ = QString::fromStdString(info.kernel);
        architecture_ = QString::fromStdString(info.architecture);
        uptime_ = formatUptime(info.uptimeSeconds);

        cpuUsage_ = info.cpuUsagePercent;

        memoryUsage_ = info.memory.usedPercent();
        memorySummary_ = QCoreApplication::translate("Pedro", "system.memory.summary").replace("{used}", formatBytes(info.memory.usedBytes())).replace("{total}", formatBytes(info.memory.totalBytes));
        emit systemChanged();

    } catch (const std::exception& error) {
        setStatusMessage(QCoreApplication::translate("Pedro", "system.errors.information").replace("{error}", error.what()));
    }
}

void Backend::loadDocument() {
    try {
        documentText_ = QString::fromStdString(Pedro::Papi::FileSystem::readFile(documentPath_.toStdString()));
        emit documentTextChanged();
        setStatusMessage(QCoreApplication::translate("Pedro", "files.status.loaded").replace("{path}", documentPath_));
    } catch (const std::exception& error) {
        setStatusMessage(QCoreApplication::translate("Pedro", "files.status.loadFailed").replace("{error}", error.what()));
    }
}

void Backend::saveDocument(const QString& contents) {
    try {
        Pedro::Papi::FileSystem::writeFile(documentPath_.toStdString(), contents.toStdString());
        documentText_ = contents;
        emit documentTextChanged();
        setStatusMessage(QCoreApplication::translate("Pedro", "files.status.saved").replace("{path}", documentPath_));
    } catch (const std::exception& error) {
        setStatusMessage(QCoreApplication::translate("Pedro", "files.status.saveFailed").replace("{error}", error.what()));
    }
}

void Backend::createDirectory(const QString& path) {
    try {
        Pedro::Papi::FileSystem::createDirectory(path.toStdString());
        setStatusMessage(QCoreApplication::translate("Pedro", "files.status.createdDirectory").replace("{path}", path));
    } catch (const std::exception& error) {
        setStatusMessage(QCoreApplication::translate("Pedro", "files.status.createDirectoryFailed").replace("{error}", error.what()));
    }
}

void Backend::refreshApplications() {

    if (applicationsRefreshPending_) {
        return;
    }

    using Result = Refresh<Pedro::Papi::Gui::Application::Snapshot>;
    auto* watcher = new QFutureWatcher<Result>(this);
    applicationsRefreshPending_ = true;

    connect(watcher, &QFutureWatcher<Result>::finished, this, [this, watcher] {
        const auto result = watcher->result();
        watcher->deleteLater();
        applicationsRefreshPending_ = false;

        if (!result.snapshot.has_value()) {
            applicationError_ = result.error;
            emit applicationsChanged();
            return;
        }

        const auto& snapshot = *result.snapshot;
        installedApplications_ = applicationValues(snapshot.installed);
        pinnedApplications_ = applicationValues(snapshot.pinned);
        applicationError_.clear();
        emit applicationsChanged();
    });

    watcher->setFuture(QtConcurrent::run([] { return readSnapshot<Pedro::Papi::Gui::Application::Manager>(); }));
}

void Backend::launchApplication(const QString& id) {

    if (activatingApplications_.contains(id)) {
        return;
    }
    activatingApplications_.insert(id);

    auto* watcher = new QFutureWatcher<QString>(this);

    connect(watcher, &QFutureWatcher<QString>::finished, this, [this, watcher, id] {
        activatingApplications_.remove(id);
        applicationError_ = watcher->result();
        watcher->deleteLater();
        emit applicationsChanged();

        if (applicationError_.isEmpty()) {
            refreshApplications();
        } else {
            qWarning() << "Application launch failed:" << applicationError_;
        }
    });

    watcher->setFuture(QtConcurrent::run([id] {
        try {
            Pedro::Papi::Gui::Application::Manager{}.activate(id.toStdString());
            return QString{};
        } catch (const std::exception& error) {
            return QString::fromUtf8(error.what());
        }
    }));
}

void Backend::setApplicationPinned(const QString& id, bool pinned) {

    try {
        applications_.setPinned(id.toStdString(), pinned);
        refreshApplications();
    } catch (const std::exception& error) {
        applicationError_ = QString::fromUtf8(error.what());
        emit applicationsChanged();
    }
}

void Backend::refreshWifi() {

    if (wifiRefreshPending_) {
        return;
    }

    using Result = Refresh<Pedro::Papi::Network::Wifi::Snapshot>;
    auto* watcher = new QFutureWatcher<Result>(this);
    wifiRefreshPending_ = true;

    connect(watcher, &QFutureWatcher<Result>::finished, this, [this, watcher] {
        const auto result = watcher->result();
        watcher->deleteLater();
        wifiRefreshPending_ = false;

        if (!result.snapshot.has_value()) {
            wifiAvailable_ = false;
            wifiEnabled_ = false;
            wifiConnected_ = false;
            connectedWifiName_.clear();
            wifiNetworks_.clear();
            wifiError_ = result.error;
            emit wifiChanged();
            return;
        }

        const auto& snapshot = *result.snapshot;
        QVariantList networks;
        networks.reserve(static_cast<qsizetype>(snapshot.accessPoints.size()));

        for (const auto& access : snapshot.accessPoints) {
            QVariantMap network;
            network.insert(QStringLiteral("name"), QString::fromStdString(access.name));
            network.insert(QStringLiteral("strength"), static_cast<int>(access.strength));
            network.insert(QStringLiteral("secured"), access.secured);
            network.insert(QStringLiteral("connected"), access.connected);
            networks.push_back(network);
        }

        wifiAvailable_ = snapshot.available;
        wifiEnabled_ = snapshot.enabled;
        wifiConnected_ = snapshot.connected;
        connectedWifiName_ = QString::fromStdString(snapshot.connectedName);
        wifiNetworks_ = std::move(networks);
        wifiError_.clear();
        emit wifiChanged();
    });

    watcher->setFuture(QtConcurrent::run([] { return readSnapshot<Pedro::Papi::Network::Wifi::Manager>(); }));
}

void Backend::setWifiEnabled(bool enabled) {
    if (!wifiAvailable_) {
        return;
    }

    try {
        wifi_.setEnabled(enabled);
        refreshWifi();
    } catch (const std::exception& error) {
        wifiError_ = QString::fromUtf8(error.what());
        emit wifiChanged();
    }
}

void Backend::scanWifi() {
    if (wifiScanning_) {
        return;
    }

    wifiScanning_ = true;
    wifiError_.clear();
    emit wifiChanged();

    try {
        wifi_.scan();
    } catch (const std::exception& error) {
        wifiScanning_ = false;
        wifiError_ = QString::fromUtf8(error.what());
        emit wifiChanged();
        return;
    }

    QTimer::singleShot(1800, this, [this] {
        refreshWifi();
        wifiScanning_ = false;
        emit wifiChanged();
    });
}

void Backend::refreshBluetooth() {

    if (bluetoothRefreshPending_) {
        return;
    }

    using Result = Refresh<Pedro::Papi::Bluetooth::Snapshot>;
    auto* watcher = new QFutureWatcher<Result>(this);
    bluetoothRefreshPending_ = true;

    connect(watcher, &QFutureWatcher<Result>::finished, this, [this, watcher] {
        const auto result = watcher->result();
        watcher->deleteLater();
        bluetoothRefreshPending_ = false;

        if (!result.snapshot.has_value()) {
            bluetoothAvailable_ = false;
            bluetoothEnabled_ = false;
            bluetoothScanning_ = false;
            bluetoothDevices_.clear();
            bluetoothError_ = result.error;

            emit bluetoothChanged();
            return;
        }

        const auto& snapshot = *result.snapshot;
        QVariantList devices;
        devices.reserve(static_cast<qsizetype>(snapshot.devices.size()));

        for (const auto& device : snapshot.devices) {
            QVariantMap value;
            value.insert(QStringLiteral("name"), QString::fromStdString(device.name));
            value.insert(QStringLiteral("icon"), QString::fromStdString(device.icon));
            value.insert(QStringLiteral("connected"), device.connected);
            value.insert(QStringLiteral("paired"), device.paired);
            devices.push_back(value);
        }

        bluetoothAvailable_ = snapshot.available;
        bluetoothEnabled_ = snapshot.enabled;
        bluetoothScanning_ = snapshot.scanning;
        bluetoothDevices_ = std::move(devices);
        bluetoothError_.clear();
        emit bluetoothChanged();
    });

    watcher->setFuture(QtConcurrent::run([] { return readSnapshot<Pedro::Papi::Bluetooth::Manager>(); }));
}

void Backend::setBluetoothEnabled(bool enabled) {
    if (!bluetoothAvailable_) {
        return;
    }

    try {
        bluetooth_.setEnabled(enabled);
        refreshBluetooth();
    } catch (const std::exception& error) {
        bluetoothError_ = QString::fromUtf8(error.what());
        emit bluetoothChanged();
    }
}

void Backend::scanBluetooth() {
    if (bluetoothScanning_ || !bluetoothAvailable_ || !bluetoothEnabled_) {
        return;
    }

    bluetoothScanning_ = true;
    bluetoothError_.clear();
    emit bluetoothChanged();

    try {
        bluetooth_.scan();
    } catch (const std::exception& error) {
        bluetoothScanning_ = false;
        bluetoothError_ = QString::fromUtf8(error.what());
        emit bluetoothChanged();
        return;
    }

    QTimer::singleShot(6000, this, [this] {
        try {
            bluetooth_.stopScan();
        } catch (const std::exception& error) {
            bluetoothError_ = QString::fromUtf8(error.what());
        }

        refreshBluetooth();
    });
}

void Backend::setStatusMessage(const QString& message) {
    if (statusMessage_ == message) {
        return;
    }
    statusMessage_ = message;
    emit statusMessageChanged();
}

QAbstractItemModel* Backend::desktopModel() {

    if (!desktop_) {
        desktop_ = std::make_unique<Pedro::Papi::Io::Desktop::Model>();
    }

    return desktop_.get();
}

QString Backend::language() const {
    return language_;
}

QString Backend::appearanceMode() const {
    return appearanceMode_;
}

qreal Backend::dockHoverScale() const {
    return dockHoverScale_;
}

QObject* Backend::clipboard() {
    return &clipboard_;
}
