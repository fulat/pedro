#pragma once
#include <QObject>
#include <QVariantMap>
namespace Pedro::Papi::Power::Battery {
    class Manager : public QObject {
            Q_OBJECT
            Q_PROPERTY(bool available READ available NOTIFY changed)
            Q_PROPERTY(int value READ value NOTIFY changed)

        public:

            explicit Manager(QObject* parent = nullptr);
            bool available() const;
            int value() const;
        signals:
            void changed();
        private slots:
            void propertiesChanged(const QString& interface, const QVariantMap& values, const QStringList& invalidated);

        private:

            void refresh();
            bool present = false;
            int percentage = 0;
    };
}
