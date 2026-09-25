#include "backend.hpp"

#include <pedro/papi/filesystem/filesystem.hpp>

#include <QDir>
#include <QStandardPaths>
#include <QVariantMap>

#include <cstdlib>
#include <exception>
#include <utility>

namespace {

    QString formatBytes(std::uint64_t bytes) {
        constexpr double gibibyte = 1024.0 * 1024.0 * 1024.0;
        return QString::number(static_cast<double>(bytes) / gibibyte, 'f', 1) + " GiB";
    }

    QString formatUptime(std::uint64_t totalSeconds) {
        const auto days = totalSeconds / 86400;
        const auto hours = (totalSeconds % 86400) / 3600;
        const auto minutes = (totalSeconds % 3600) / 60;
        if (days > 0) {
            return QStringLiteral("%1d %2h %3m").arg(days).arg(hours).arg(minutes);
        }
        return QStringLiteral("%1h %2m").arg(hours).arg(minutes);
    }

} // namespace

Backend::Backend(QObject* parent) : QObject(parent) {
    auto documents = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    if (documents.isEmpty() || !QDir(documents).exists()) {
        documents = QDir::homePath();
    }
    documentPath_ = QDir(documents).filePath(QStringLiteral("pedro-notes.txt"));

    connect(&refreshTimer_, &QTimer::timeout, this, &Backend::refreshSystem);
    refreshTimer_.start(1000);

    connect(&wifiRefreshTimer_, &QTimer::timeout, this, &Backend::refreshWifi);
    wifiRefreshTimer_.start(10000);

    connect(&bluetoothRefreshTimer_, &QTimer::timeout, this, &Backend::refreshBluetooth);
    bluetoothRefreshTimer_.start(5000);

    refreshSystem();
    refreshWifi();
    refreshBluetooth();
}

bool Backend::developmentMode() const {
    return std::getenv("PEDRO_DEVELOPMENT_MODE") != nullptr;
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
        if (info.cpuUsagePercent.has_value()) {
            cpuUsage_ = *info.cpuUsagePercent;
        }
        memoryUsage_ = info.memory.usedPercent();
        memorySummary_ = QStringLiteral("%1 of %2 used").arg(formatBytes(info.memory.usedBytes()), formatBytes(info.memory.totalBytes));
        emit systemChanged();
    } catch (const std::exception& error) {
        setStatusMessage(QStringLiteral("System information error: %1").arg(error.what()));
    }
}

void Backend::loadDocument() {
    try {
        documentText_ = QString::fromStdString(Pedro::Papi::Filesystem::readFile(documentPath_.toStdString()));
        emit documentTextChanged();
        setStatusMessage(QStringLiteral("Loaded %1 through PAPI").arg(documentPath_));
    } catch (const std::exception& error) {
        setStatusMessage(QStringLiteral("Load failed: %1").arg(error.what()));
    }
}

void Backend::saveDocument(const QString& contents) {
    try {
        Pedro::Papi::Filesystem::writeFile(documentPath_.toStdString(), contents.toStdString());
        documentText_ = contents;
        emit documentTextChanged();
        setStatusMessage(QStringLiteral("Saved %1 through PAPI").arg(documentPath_));
    } catch (const std::exception& error) {
        setStatusMessage(QStringLiteral("Save failed: %1").arg(error.what()));
    }
}

void Backend::createDirectory(const QString& path) {
    try {
        Pedro::Papi::Filesystem::createDirectory(path.toStdString());
        setStatusMessage(QStringLiteral("Created %1 through PAPI").arg(path));
    } catch (const std::exception& error) {
        setStatusMessage(QStringLiteral("Create folder failed: %1").arg(error.what()));
    }
}

void Backend::refreshWifi() {
    try {
        const auto snapshot = wifi_.snapshot();
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
    } catch (const std::exception& error) {
        wifiAvailable_ = false;
        wifiEnabled_ = false;
        wifiConnected_ = false;
        connectedWifiName_.clear();
        wifiNetworks_.clear();
        wifiError_ = QString::fromUtf8(error.what());
        emit wifiChanged();
    }
}

void Backend::setWifiEnabled(bool enabled) {
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
    try {
        const auto snapshot = bluetooth_.snapshot();
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
    } catch (const std::exception& error) {
        bluetoothAvailable_ = false;
        bluetoothEnabled_ = false;
        bluetoothScanning_ = false;
        bluetoothDevices_.clear();
        bluetoothError_ = QString::fromUtf8(error.what());
        emit bluetoothChanged();
    }
}

void Backend::setBluetoothEnabled(bool enabled) {
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
