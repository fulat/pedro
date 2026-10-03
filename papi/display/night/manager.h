#pragma once

#include <QObject>

struct _GSettings;

namespace Pedro::Papi::Display::Night {

    class Manager final : public QObject {
            Q_OBJECT
            Q_PROPERTY(bool available READ available NOTIFY changed)
            Q_PROPERTY(bool active READ active NOTIFY changed)
            Q_PROPERTY(QString error READ error NOTIFY changed)

        public:

            explicit Manager(QObject* parent = nullptr);

            ~Manager() override;

            bool available() const;

            bool active() const;

            QString error() const;

            Q_INVOKABLE void toggle();

        signals:
            void changed();

        private:

            _GSettings* settings = nullptr;
            QString failure;
    };
}
