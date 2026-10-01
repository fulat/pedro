#pragma once

#include <pedro/papi/gui/application/manager.hpp>
#include <pedro/papi/io/bluetooth/manager.hpp>
#include <pedro/papi/io/network/wifi/manager.hpp>
#include <pedro/papi/system/system.hpp>
#include <pedro/papi/utils/utils.hpp>

#include <QUrl>
#include <QObject>
#include <QString>
#include <QTimer>
#include <QVariantList>
#include <QtQmlIntegration/qqmlintegration.h>

class Backend final : public QObject {
        Q_OBJECT
        QML_NAMED_ELEMENT(Papi)
        QML_SINGLETON
        Q_PROPERTY(bool developmentMode READ developmentMode CONSTANT)
        Q_PROPERTY(QString hostname READ hostname NOTIFY systemChanged)
        Q_PROPERTY(QString kernel READ kernel NOTIFY systemChanged)
        Q_PROPERTY(QString architecture READ architecture NOTIFY systemChanged)
        Q_PROPERTY(QString uptime READ uptime NOTIFY systemChanged)
        Q_PROPERTY(double cpuUsage READ cpuUsage NOTIFY systemChanged)
        Q_PROPERTY(double memoryUsage READ memoryUsage NOTIFY systemChanged)
        Q_PROPERTY(QString memorySummary READ memorySummary NOTIFY systemChanged)
        Q_PROPERTY(QString documentPath READ documentPath WRITE setDocumentPath NOTIFY documentPathChanged)
        Q_PROPERTY(QString documentText READ documentText NOTIFY documentTextChanged)
        Q_PROPERTY(QString statusMessage READ statusMessage NOTIFY statusMessageChanged)
        Q_PROPERTY(QVariantList installedApplications READ installedApplications NOTIFY applicationsChanged)
        Q_PROPERTY(QVariantList pinnedApplications READ pinnedApplications NOTIFY applicationsChanged)
        Q_PROPERTY(QString applicationError READ applicationError NOTIFY applicationsChanged)
        Q_PROPERTY(bool wifiAvailable READ wifiAvailable NOTIFY wifiChanged)
        Q_PROPERTY(bool wifiEnabled READ wifiEnabled NOTIFY wifiChanged)
        Q_PROPERTY(bool wifiConnected READ wifiConnected NOTIFY wifiChanged)
        Q_PROPERTY(QString connectedWifiName READ connectedWifiName NOTIFY wifiChanged)
        Q_PROPERTY(bool wifiScanning READ wifiScanning NOTIFY wifiChanged)
        Q_PROPERTY(QString wifiError READ wifiError NOTIFY wifiChanged)
        Q_PROPERTY(QVariantList wifiNetworks READ wifiNetworks NOTIFY wifiChanged)
        Q_PROPERTY(bool bluetoothAvailable READ bluetoothAvailable NOTIFY bluetoothChanged)
        Q_PROPERTY(bool bluetoothEnabled READ bluetoothEnabled NOTIFY bluetoothChanged)
        Q_PROPERTY(bool bluetoothScanning READ bluetoothScanning NOTIFY bluetoothChanged)
        Q_PROPERTY(QString bluetoothError READ bluetoothError NOTIFY bluetoothChanged)
        Q_PROPERTY(QVariantList bluetoothDevices READ bluetoothDevices NOTIFY bluetoothChanged)

        Q_PROPERTY(QUrl wallpaper READ wallpaper NOTIFY wallpaperChanged)

    public:

        explicit Backend(QObject* parent = nullptr);

        [[nodiscard]] bool developmentMode() const;
        [[nodiscard]] QString hostname() const;
        [[nodiscard]] QString kernel() const;
        [[nodiscard]] QString architecture() const;
        [[nodiscard]] QString uptime() const;
        [[nodiscard]] double cpuUsage() const;
        [[nodiscard]] double memoryUsage() const;
        [[nodiscard]] QString memorySummary() const;
        [[nodiscard]] QString documentPath() const;
        [[nodiscard]] QString documentText() const;
        [[nodiscard]] QString statusMessage() const;
        [[nodiscard]] QVariantList installedApplications() const;
        [[nodiscard]] QVariantList pinnedApplications() const;
        [[nodiscard]] QString applicationError() const;
        [[nodiscard]] bool wifiAvailable() const;
        [[nodiscard]] bool wifiEnabled() const;
        [[nodiscard]] bool wifiConnected() const;
        [[nodiscard]] QString connectedWifiName() const;
        [[nodiscard]] bool wifiScanning() const;
        [[nodiscard]] QString wifiError() const;
        [[nodiscard]] QVariantList wifiNetworks() const;
        [[nodiscard]] bool bluetoothAvailable() const;
        [[nodiscard]] bool bluetoothEnabled() const;
        [[nodiscard]] bool bluetoothScanning() const;
        [[nodiscard]] QString bluetoothError() const;
        [[nodiscard]] QVariantList bluetoothDevices() const;

        [[nodiscard]] QUrl wallpaper() const;

        void setDocumentPath(const QString& path);

        Q_INVOKABLE void refreshSystem();
        Q_INVOKABLE void loadDocument();
        Q_INVOKABLE void saveDocument(const QString& contents);
        Q_INVOKABLE void createDirectory(const QString& path);
        Q_INVOKABLE void refreshApplications();
        Q_INVOKABLE void launchApplication(const QString& id);
        Q_INVOKABLE void setApplicationPinned(const QString& id, bool pinned);
        Q_INVOKABLE void refreshWifi();
        Q_INVOKABLE void setWifiEnabled(bool enabled);
        Q_INVOKABLE void scanWifi();
        Q_INVOKABLE void refreshBluetooth();
        Q_INVOKABLE void setBluetoothEnabled(bool enabled);
        Q_INVOKABLE void scanBluetooth();

    signals:
        void systemChanged();
        void documentPathChanged();
        void documentTextChanged();
        void statusMessageChanged();
        void applicationsChanged();
        void wifiChanged();
        void bluetoothChanged();
        void wallpaperChanged();

    private:

        void setStatusMessage(const QString& message);

        Pedro::Papi::System system_;
        Pedro::Papi::Gui::Application::Manager applications_;
        Pedro::Papi::Network::Wifi::Manager wifi_;
        Pedro::Papi::Bluetooth::Manager bluetooth_;

        QTimer refreshTimer_;
        QTimer applicationsRefreshTimer_;
        QTimer wifiRefreshTimer_;
        QTimer bluetoothRefreshTimer_;

        QString hostname_;
        QString kernel_;
        QString architecture_;
        QString uptime_;

        double cpuUsage_{-1.0};
        double memoryUsage_{0.0};

        QString memorySummary_;
        QString documentPath_;
        QString documentText_;
        QString applicationError_;
        QString bluetoothError_;
        QString statusMessage_;
        QString connectedWifiName_;
        QString wifiError_;
        QUrl wallpaper_;

        bool wifiAvailable_{false};
        bool wifiEnabled_{false};
        bool wifiConnected_{false};
        bool wifiRefreshPending_{false};
        bool wifiScanning_{false};

        bool bluetoothAvailable_{false};
        bool bluetoothEnabled_{false};
        bool bluetoothScanning_{false};
        bool bluetoothRefreshPending_{false};

        bool applicationsRefreshPending_{false};

        QVariantList installedApplications_;
        QVariantList pinnedApplications_;
        QVariantList wifiNetworks_;
        QVariantList bluetoothDevices_;
};
