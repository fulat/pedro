#include "manager.hpp"

#include <QDBusConnection>
#include <QDBusError>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDBusMetaType>
#include <QDBusObjectPath>
#include <QDBusReply>
#include <QDBusVariant>
#include <QMap>
#include <QString>
#include <QVariantMap>

#include <algorithm>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

using BluetoothInterfaceMap = QMap<QString, QVariantMap>;
using BluetoothManagedObjects = QMap<QDBusObjectPath, BluetoothInterfaceMap>;

Q_DECLARE_METATYPE(BluetoothInterfaceMap)
Q_DECLARE_METATYPE(BluetoothManagedObjects)

namespace Pedro::Papi::Bluetooth {

    namespace {

        constexpr auto service = "org.bluez";
        constexpr auto managerPath = "/";
        constexpr auto objectManagerInterface = "org.freedesktop.DBus.ObjectManager";
        constexpr auto propertiesInterface = "org.freedesktop.DBus.Properties";
        constexpr auto adapterInterface = "org.bluez.Adapter1";
        constexpr auto deviceInterface = "org.bluez.Device1";

        std::runtime_error dbusError(const std::string& operation, const QDBusError& error) {
            return std::runtime_error(operation + ": " + error.message().toStdString());
        }

        QDBusConnection systemBus() {
            const auto bus = QDBusConnection::systemBus();

            if (!bus.isConnected()) {
                throw std::runtime_error("Unable to connect to the system D-Bus");
            }

            return bus;
        }

        void registerDbusTypes() {
            static const bool registered = [] {
                qDBusRegisterMetaType<BluetoothInterfaceMap>();
                qDBusRegisterMetaType<BluetoothManagedObjects>();
                return true;
            }();

            (void)registered;
        }

        BluetoothManagedObjects managedObjects(const QDBusConnection& bus) {
            registerDbusTypes();

            QDBusInterface manager(service, managerPath, objectManagerInterface, bus);

            if (!manager.isValid()) {
                throw dbusError("BlueZ is unavailable", manager.lastError());
            }

            const QDBusReply<BluetoothManagedObjects> reply = manager.call(QStringLiteral("GetManagedObjects"));

            if (!reply.isValid()) {
                throw dbusError("Unable to read Bluetooth devices", reply.error());
            }

            return reply.value();
        }

        std::vector<QString> adapterPaths(const BluetoothManagedObjects& objects) {
            std::vector<QString> paths;

            for (auto object = objects.cbegin(); object != objects.cend(); ++object) {
                if (object.value().contains(QString::fromLatin1(adapterInterface))) {
                    paths.push_back(object.key().path());
                }
            }

            return paths;
        }

        void callAdapters(const QString& method, const std::string& operation) {
            const auto bus = systemBus();
            const auto paths = adapterPaths(managedObjects(bus));

            if (paths.empty()) {
                throw std::runtime_error("No Bluetooth adapter is available");
            }

            bool succeeded = false;
            QDBusError lastError;

            for (const auto& path : paths) {
                QDBusInterface adapter(service, path, adapterInterface, bus);

                const auto reply = adapter.call(method);

                if (reply.type() != QDBusMessage::ErrorMessage) {
                    succeeded = true;
                    continue;
                }

                lastError = QDBusError(reply);
            }

            if (!succeeded) {
                throw dbusError(operation, lastError);
            }
        }

    } // namespace

    Snapshot Manager::snapshot() const {
        const auto bus = systemBus();
        const auto objects = managedObjects(bus);

        Snapshot result;

        for (auto object = objects.cbegin(); object != objects.cend(); ++object) {
            const auto& interfaces = object.value();

            const auto adapter = interfaces.constFind(QString::fromLatin1(adapterInterface));

            if (adapter == interfaces.cend()) {
                continue;
            }

            result.available = true;

            result.enabled = result.enabled || adapter->value(QStringLiteral("Powered")).toBool();

            result.scanning = result.scanning || adapter->value(QStringLiteral("Discovering")).toBool();
        }

        if (!result.available || !result.enabled) {
            return result;
        }

        for (auto object = objects.cbegin(); object != objects.cend(); ++object) {
            const auto& interfaces = object.value();

            const auto device = interfaces.constFind(QString::fromLatin1(deviceInterface));

            if (device == interfaces.cend()) {
                continue;
            }

            Device value;

            value.name = device->value(QStringLiteral("Alias"), device->value(QStringLiteral("Name"))).toString().toStdString();

            value.icon = device->value(QStringLiteral("Icon")).toString().toStdString();

            value.connected = device->value(QStringLiteral("Connected")).toBool();

            value.paired = device->value(QStringLiteral("Paired")).toBool();

            if (value.name.empty()) {
                value.name = "Dispositivo Bluetooth";
            }

            result.devices.push_back(std::move(value));
        }

        std::sort(result.devices.begin(), result.devices.end(), [](const Device& left, const Device& right) {
            if (left.connected != right.connected) {
                return left.connected;
            }

            if (left.paired != right.paired) {
                return left.paired;
            }

            return left.name < right.name;
        });

        return result;
    }

    void Manager::setEnabled(bool enabled) const {
        const auto bus = systemBus();
        const auto paths = adapterPaths(managedObjects(bus));

        if (paths.empty()) {
            throw std::runtime_error("No Bluetooth adapter is available");
        }

        bool succeeded = false;
        QDBusError lastError;

        for (const auto& path : paths) {
            QDBusInterface properties(service, path, propertiesInterface, bus);

            const auto value = QVariant::fromValue(QDBusVariant(QVariant::fromValue(enabled)));

            const auto reply = properties.call(QStringLiteral("Set"), QString::fromLatin1(adapterInterface), QStringLiteral("Powered"), value);

            if (reply.type() != QDBusMessage::ErrorMessage) {
                succeeded = true;
                continue;
            }

            lastError = QDBusError(reply);
        }

        if (!succeeded) {
            throw dbusError("Unable to change Bluetooth state", lastError);
        }
    }


    bool Manager::isAvailable() const {
        const auto bus = systemBus();
        const auto objects = managedObjects(bus);

        for (auto object = objects.cbegin(); object != objects.cend(); ++object) {
            if (object.value().contains(QString::fromLatin1(adapterInterface))) {
                return true;
            }
        }

        return false;
    }

    void Manager::scan() const {
        callAdapters(QStringLiteral("StartDiscovery"), "Unable to start Bluetooth discovery");
    }

    void Manager::stopScan() const {
        callAdapters(QStringLiteral("StopDiscovery"), "Unable to stop Bluetooth discovery");
    }

} // namespace Pedro::Papi::Bluetooth