#pragma once

#include <QObject>
#include <QVariantMap>

namespace Pedro::Papi::Power::Profile {

    class Manager final : public QObject {
            Q_OBJECT
            Q_PROPERTY(bool available READ available NOTIFY changed)
            Q_PROPERTY(bool active READ active NOTIFY changed)
            Q_PROPERTY(bool busy READ busy NOTIFY changed)
            Q_PROPERTY(QString error READ error NOTIFY changed)

        public:

            explicit Manager(QObject* parent = nullptr);

            bool available() const;

            bool active() const;

            bool busy() const;

            QString error() const;

            Q_INVOKABLE void toggle();

        signals:
            void changed();

        private slots:
            void propertiesChanged(const QString& interface, const QVariantMap& values, const QStringList& invalidated);

        private:

            void refresh();

            QString current;
            QString previous = "balanced";
            QString failure;
            bool supported = false;
            bool pending = false;
    };
}
