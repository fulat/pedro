#pragma once

#include <QObject>

namespace Pedro::Papi::Gui::Capture {
    class Manager final : public QObject {
            Q_OBJECT
            Q_PROPERTY(bool busy READ busy NOTIFY changed)
            Q_PROPERTY(QString error READ error NOTIFY changed)

        public:

            explicit Manager(QObject* parent = nullptr);

            bool busy() const;

            QString error() const;

            Q_INVOKABLE void open();

        signals:
            void changed();

        private:

            bool pending = false;
            QString failure;
    };
}
