#pragma once

#include <pedro/papi/gui/application/manager.hpp>
#include <pedro/papi/io/bluetooth/manager.hpp>
#include <pedro/papi/io/desktop/model.hpp>
#include <pedro/papi/gui/clipboard/manager.hpp>
#include <pedro/papi/io/transfer/manager.hpp>
#include <pedro/papi/io/network/wifi/manager.hpp>
#include <pedro/papi/system/system.hpp>
#include <pedro/papi/utils/utils.hpp>
#include <pedro/papi/config/store.hpp>
#include <pedro/papi/display/brightness/manager.h>
#include <pedro/papi/audio/volume/manager.h>
#include <pedro/papi/power/battery/manager.h>
#include <pedro/papi/power/profile/manager.h>
#include <pedro/papi/gui/focus/manager.h>
#include <pedro/papi/gui/capture/manager.h>
#include <pedro/papi/display/night/manager.h>
#include <pedro/papi/display/keyboard/manager.h>
#include <pedro/papi/network/connection/manager.h>

#include <pedro/papi/gui/preview/manager.h>

#include <QUrl>
#include <QObject>
#include <QString>
#include <QTimer>
#include <QVariantList>
#include <QSet>
#include <QtQmlIntegration/qqmlintegration.h>

#include <memory>

class QQmlEngine;
class QJSEngine;

class Backend final : public QObject {
        Q_OBJECT
        QML_NAMED_ELEMENT(Papi)
        QML_SINGLETON
        Q_PROPERTY(QAbstractItemModel* desktopModel READ desktopModel CONSTANT)
        Q_PROPERTY(QObject* clipboard READ clipboard CONSTANT)
        Q_PROPERTY(QObject* fileTransfer READ fileTransfer CONSTANT)
        Q_PROPERTY(QObject* screenBrightness READ screenBrightness CONSTANT)
        Q_PROPERTY(QObject* audioVolume READ audioVolume CONSTANT)
        Q_PROPERTY(QObject* battery READ battery CONSTANT)
        Q_PROPERTY(QObject* powerSaving READ powerSaving CONSTANT)
        Q_PROPERTY(QObject* focusMode READ focusMode CONSTANT)
        Q_PROPERTY(QObject* nightLight READ nightLight CONSTANT)
        Q_PROPERTY(QObject* keyboard READ keyboard CONSTANT)
        Q_PROPERTY(QObject* capture READ capture CONSTANT)
        Q_PROPERTY(QObject* networkConnection READ networkConnection CONSTANT)
        Q_PROPERTY(QObject* preview READ preview CONSTANT)
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
        Q_PROPERTY(QString language READ language NOTIFY languageChanged)
        Q_PROPERTY(QString appearanceMode READ appearanceMode NOTIFY appearanceModeChanged)
        Q_PROPERTY(qreal dockHoverScale READ dockHoverScale NOTIFY dockHoverScaleChanged)

    public:

        // A required parent argument makes Qt use create() rather than construct
        // another QML singleton alongside the context backend.
        explicit Backend(QObject* parent);

        static Backend* create(QQmlEngine* engine, QJSEngine* scriptEngine);

        static void setInstance(Backend* backend);

        QAbstractItemModel* desktopModel();

        QObject* clipboard();

        QObject* fileTransfer();

        Q_INVOKABLE int dragFiles(QObject* source, const QVariantList& urls);

        QObject* screenBrightness();

        QObject* audioVolume();

        QObject* battery();

        QObject* powerSaving();

        QObject* focusMode();

        QObject* nightLight();

        QObject* keyboard();

        QObject* capture();

        QObject* networkConnection();

        [[nodiscard]] QString hostname() const;
        [[nodiscard]] QString kernel() const;
        [[nodiscard]] QString architecture() const;
        [[nodiscard]] QString uptime() const;
        [[nodiscard]] QString memorySummary() const;
        [[nodiscard]] QString documentPath() const;
        [[nodiscard]] QString documentText() const;
        [[nodiscard]] QString statusMessage() const;
        [[nodiscard]] QString applicationError() const;
        [[nodiscard]] QString connectedWifiName() const;
        [[nodiscard]] QString wifiError() const;
        [[nodiscard]] QString bluetoothError() const;

        [[nodiscard]] QVariantList bluetoothDevices() const;
        [[nodiscard]] QVariantList installedApplications() const;
        [[nodiscard]] QVariantList pinnedApplications() const;
        [[nodiscard]] QVariantList wifiNetworks() const;

        [[nodiscard]] double cpuUsage() const;
        [[nodiscard]] double memoryUsage() const;

        [[nodiscard]] bool developmentMode() const;

        [[nodiscard]] bool wifiScanning() const;
        [[nodiscard]] bool wifiAvailable() const;
        [[nodiscard]] bool wifiEnabled() const;
        [[nodiscard]] bool wifiConnected() const;

        [[nodiscard]] bool bluetoothAvailable() const;
        [[nodiscard]] bool bluetoothEnabled() const;
        [[nodiscard]] bool bluetoothScanning() const;

        [[nodiscard]] QUrl wallpaper() const;

        QString language() const;

        QString appearanceMode() const;

        qreal dockHoverScale() const;

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

        QObject* preview();

        Q_INVOKABLE void placeWindow(QObject* window, const QString& shellTitle);

        Q_INVOKABLE void activateWindow(QObject* window);

        Q_INVOKABLE void openPreview(const QUrl& source, const QVariantList& siblings = {}, bool activateExisting = true);

        Q_INVOKABLE void releasePreview(QObject* session);

    signals:
        void previewRequested(QObject* session);
        void systemChanged();
        void documentPathChanged();
        void documentTextChanged();
        void statusMessageChanged();
        void applicationsChanged();
        void wifiChanged();
        void bluetoothChanged();
        void wallpaperChanged();

        void languageChanged();

        void appearanceModeChanged();

        void dockHoverScaleChanged();

    private:

        void setStatusMessage(const QString& message);

        Pedro::Papi::Gui::Clipboard::Manager clipboard_;

        Pedro::Papi::Io::Transfer::Manager transfer_;

        std::unique_ptr<Pedro::Papi::Io::Desktop::Model> desktop_;

        Pedro::Papi::System system_;
        Pedro::Papi::Gui::Application::Manager applications_;
        Pedro::Papi::Network::Wifi::Manager wifi_;
        Pedro::Papi::Bluetooth::Manager bluetooth_;

        Pedro::Papi::Display::Brightness::Manager brightness_;
        Pedro::Papi::Audio::Volume::Manager volume_;
        Pedro::Papi::Power::Battery::Manager battery_;
        Pedro::Papi::Power::Profile::Manager profile_;
        Pedro::Papi::Gui::Focus::Manager focus_;
        Pedro::Papi::Gui::Capture::Manager capture_;
        Pedro::Papi::Display::Night::Manager night_;
        Pedro::Papi::Display::Keyboard::Manager keyboard_;
        Pedro::Papi::Network::Connection::Manager connection_;

        Pedro::Papi::Gui::Preview::Manager preview_;

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

        QSet<QString> activatingApplications_;
        QString bluetoothError_;
        QString statusMessage_;
        QString connectedWifiName_;
        QString wifiError_;
        QUrl wallpaper_;

        QString language_;

        QString appearanceMode_ = "light";

        qreal dockHoverScale_ = 1.20;

        Pedro::Papi::Config::Store configuration_;

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
