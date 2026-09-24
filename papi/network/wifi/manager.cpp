#include "manager.hpp"

#include <QByteArray>
#include <QDBusConnection>
#include <QDBusError>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QDBusReply>
#include <QDBusVariant>
#include <QString>
#include <QVariantMap>

#include <algorithm>
#include <map>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

namespace Pedro::Papi::Network::Wifi {
    namespace {

        constexpr auto service = "org.freedesktop.NetworkManager";
        constexpr auto managerPath = "/org/freedesktop/NetworkManager";
        constexpr auto managerInterface = "org.freedesktop.NetworkManager";
        constexpr auto propertiesInterface = "org.freedesktop.DBus.Properties";
        constexpr auto deviceInterface = "org.freedesktop.NetworkManager.Device";
        constexpr auto wirelessInterface = "org.freedesktop.NetworkManager.Device.Wireless";
        constexpr auto accessInterface = "org.freedesktop.NetworkManager.AccessPoint";
        constexpr std::uint32_t wirelessDevice = 2;

        std::runtime_error dbusError(const std::string& operation, const QDBusError& error) {

            return std::runtime_error(operation + ": " + error.message().toStdString());
        }

        QDBusConnection systemBus() {

            auto bus = QDBusConnection::systemBus();

            if (!bus.isConnected()) {
                throw std::runtime_error("Unable to connect to the system D-Bus");
            }

            return bus;
        }

        std::vector<QDBusObjectPath> wirelessDevices(const QDBusConnection& bus) {

            QDBusInterface manager(service, managerPath, managerInterface, bus);

            if (!manager.isValid()) {
                throw dbusError("NetworkManager is unavailable", manager.lastError());
            }

            const QDBusReply<QList<QDBusObjectPath>> reply = manager.call(QStringLiteral("GetDevices"));

            if (!reply.isValid()) {
                throw dbusError("Unable to list network devices", reply.error());
            }

            std::vector<QDBusObjectPath> devices;

            for (const auto& path : reply.value()) {
                QDBusInterface device(service, path.path(), deviceInterface, bus);

                if (device.property("DeviceType").toUInt() == wirelessDevice) {
                    devices.push_back(path);
                }
            }

            return devices;
        }

        Access readAccess(const QDBusConnection& bus, const QDBusObjectPath& path, const QString& activePath) {

            QDBusInterface access(service, path.path(), accessInterface, bus);
            const auto name = QString::fromUtf8(access.property("Ssid").toByteArray());
            const auto flags = access.property("Flags").toUInt();
            const auto wpaFlags = access.property("WpaFlags").toUInt();
            const auto rsnFlags = access.property("RsnFlags").toUInt();

            Access point;
            point.name = name.toStdString();
            point.strength = static_cast<std::uint8_t>(std::min(access.property("Strength").toUInt(), 100U));
            point.secured = flags != 0 || wpaFlags != 0 || rsnFlags != 0;
            point.connected = path.path() == activePath;
            return point;
        }

    } // namespace

    Snapshot Manager::snapshot() const {

        const auto bus = systemBus();
        QDBusInterface manager(service, managerPath, managerInterface, bus);

        if (!manager.isValid()) {
            throw dbusError("NetworkManager is unavailable", manager.lastError());
        }

        Snapshot result;
        result.enabled = manager.property("WirelessEnabled").toBool();
        const auto devices = wirelessDevices(bus);
        result.available = !devices.empty();

        if (!result.available || !result.enabled) {
            return result;
        }

        std::map<std::string, Access> points;

        for (const auto& devicePath : devices) {
            QDBusInterface wireless(service, devicePath.path(), wirelessInterface, bus);
            const auto activePath = wireless.property("ActiveAccessPoint").value<QDBusObjectPath>().path();
            const QDBusReply<QList<QDBusObjectPath>> reply = wireless.call(QStringLiteral("GetAccessPoints"));

            if (!reply.isValid()) {
                continue;
            }

            for (const auto& accessPath : reply.value()) {
                auto point = readAccess(bus, accessPath, activePath);

                if (point.name.empty()) {
                    continue;
                }

                if (point.connected) {
                    result.connected = true;
                    result.connectedName = point.name;
                }

                const auto existing = points.find(point.name);

                if (existing == points.end() || point.connected || point.strength > existing->second.strength) {
                    points[point.name] = std::move(point);
                }
            }
        }

        result.accessPoints.reserve(points.size());

        for (auto& [name, point] : points) {
            result.accessPoints.push_back(std::move(point));
        }

        std::sort(result.accessPoints.begin(), result.accessPoints.end(), [](const Access& left, const Access& right) {
            if (left.connected != right.connected) {
                return left.connected;
            }

            if (left.strength != right.strength) {
                return left.strength > right.strength;
            }

            return left.name < right.name;
        });

        return result;
    }

    void Manager::setEnabled(bool enabled) const {

        const auto bus = systemBus();
        QDBusInterface properties(service, managerPath, propertiesInterface, bus);

        if (!properties.isValid()) {
            throw dbusError("NetworkManager is unavailable", properties.lastError());
        }

        const auto value = QVariant::fromValue(QDBusVariant(QVariant::fromValue(enabled)));
        const auto reply = properties.call(QStringLiteral("Set"), QString::fromLatin1(managerInterface), QStringLiteral("WirelessEnabled"), value);

        if (reply.type() == QDBusMessage::ErrorMessage) {
            throw dbusError("Unable to change Wi-Fi state", QDBusError(reply));
        }
    }

    void Manager::scan() const {

        const auto bus = systemBus();
        const auto devices = wirelessDevices(bus);

        if (devices.empty()) {
            throw std::runtime_error("No Wi-Fi device is available");
        }

        bool requested = false;
        QDBusError lastError;

        for (const auto& devicePath : devices) {
            QDBusInterface wireless(service, devicePath.path(), wirelessInterface, bus);
            const auto reply = wireless.call(QStringLiteral("RequestScan"), QVariantMap{});

            if (reply.type() != QDBusMessage::ErrorMessage) {
                requested = true;
            } else {
                lastError = QDBusError(reply);
            }
        }

        if (!requested) {
            throw dbusError("Unable to request a Wi-Fi scan", lastError);
        }
    }

} // namespace Pedro::Papi::Network::Wifi
