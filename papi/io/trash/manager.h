#pragma once

#include <QObject>
#include <QVariantList>

namespace Pedro::Papi::Io::Trash {

    class Manager : public QObject {
            Q_OBJECT
            Q_PROPERTY(bool busy READ busy NOTIFY changed)
            Q_PROPERTY(QString error READ error NOTIFY changed)

        public:

            explicit Manager(QObject* parent = nullptr);

            bool busy() const;

            QString error() const;

            Q_INVOKABLE void move(const QVariantList& urls);

            Q_INVOKABLE void restore(const QVariantList& urls);

            Q_INVOKABLE void remove(const QVariantList& urls);

            Q_INVOKABLE void empty();

        signals:
            void changed();

            void failed(const QString& message);

        private:

            enum class Operation {
                Move,
                Restore,
                Remove,
                Empty
            };

            void run(Operation operation, const QVariantList& urls);

            bool active = false;

            QString failure;
    };

}
