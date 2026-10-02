#pragma once
#include <QObject>
#include <QVariantMap>
namespace Pedro::Papi::Network::Connection {
    class Manager : public QObject {
            Q_OBJECT
            Q_PROPERTY(QString type READ type NOTIFY changed)
            Q_PROPERTY(QString name READ name NOTIFY changed)

        public:

            explicit Manager(QObject* parent = nullptr);
            QString type() const;
            QString name() const;
        signals:
            void changed();
        private slots:
            void propertiesChanged(const QString& interface, const QVariantMap& values, const QStringList& invalidated);

        private:

            void refresh();
            QString kind = "none";
            QString label;
            int revision = 0;
    };
}
