#pragma once

#include <pedro/papi/network/wifi/manager.hpp>
#include <pedro/papi/system/system.hpp>

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
        Q_PROPERTY(bool wifiAvailable READ wifiAvailable NOTIFY wifiChanged)
        Q_PROPERTY(bool wifiEnabled READ wifiEnabled NOTIFY wifiChanged)
        Q_PROPERTY(bool wifiConnected READ wifiConnected NOTIFY wifiChanged)
        Q_PROPERTY(QString connectedWifiName READ connectedWifiName NOTIFY wifiChanged)
        Q_PROPERTY(bool wifiScanning READ wifiScanning NOTIFY wifiChanged)
        Q_PROPERTY(QString wifiError READ wifiError NOTIFY wifiChanged)
        Q_PROPERTY(QVariantList wifiNetworks READ wifiNetworks NOTIFY wifiChanged)

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
        [[nodiscard]] bool wifiAvailable() const;
        [[nodiscard]] bool wifiEnabled() const;
        [[nodiscard]] bool wifiConnected() const;
        [[nodiscard]] QString connectedWifiName() const;
        [[nodiscard]] bool wifiScanning() const;
        [[nodiscard]] QString wifiError() const;
        [[nodiscard]] QVariantList wifiNetworks() const;

        void setDocumentPath(const QString& path);

        Q_INVOKABLE void refreshSystem();
        Q_INVOKABLE void loadDocument();
        Q_INVOKABLE void saveDocument(const QString& contents);
        Q_INVOKABLE void createDirectory(const QString& path);
        Q_INVOKABLE void refreshWifi();
        Q_INVOKABLE void setWifiEnabled(bool enabled);
        Q_INVOKABLE void scanWifi();

    signals:
        void systemChanged();
        void documentPathChanged();
        void documentTextChanged();
        void statusMessageChanged();
        void wifiChanged();

    private:

        void setStatusMessage(const QString& message);

        Pedro::Papi::System system_;
        Pedro::Papi::Network::Wifi::Manager wifi_;
        QTimer refreshTimer_;
        QTimer wifiRefreshTimer_;
        QString hostname_;
        QString kernel_;
        QString architecture_;
        QString uptime_;
        double cpuUsage_{-1.0};
        double memoryUsage_{0.0};
        QString memorySummary_;
        QString documentPath_;
        QString documentText_;
        QString statusMessage_;
        bool wifiAvailable_{false};
        bool wifiEnabled_{false};
        bool wifiConnected_{false};
        QString connectedWifiName_;
        bool wifiScanning_{false};
        QString wifiError_;
        QVariantList wifiNetworks_;
};
