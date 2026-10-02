#pragma once

#include <QObject>
#include <QTimer>
#include <QVariantMap>

class QDBusServiceWatcher;

namespace Pedro::Papi::Display::Brightness {

    class Manager : public QObject {
            Q_OBJECT
            Q_PROPERTY(bool available READ available NOTIFY changed)
            Q_PROPERTY(int value READ value NOTIFY changed)
            Q_PROPERTY(QString error READ error NOTIFY changed)

        public:

            explicit Manager(QObject* parent = nullptr);

            bool available() const;

            int value() const;

            QString error() const;

            Q_INVOKABLE void setValue(int percentage);

        signals:
            void changed();

        private slots:
            void propertiesChanged(const QString& interface, const QVariantMap& properties, const QStringList& invalidated);

        private:

            void refresh();

            void apply(int percentage);

            void write();

            QDBusServiceWatcher* serviceWatcher;
            QTimer debounce;
            bool supported = false;
            bool writing = false;
            int percentage = 0;
            int requested = -1;
            int revision = 0;
            QString failure;
    };
}
