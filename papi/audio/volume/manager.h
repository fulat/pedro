#pragma once

#include <QObject>
#include <QProcess>
#include <QTimer>

namespace Pedro::Papi::Audio::Volume {

    class Manager : public QObject {
            Q_OBJECT
            Q_PROPERTY(bool available READ available NOTIFY changed)
            Q_PROPERTY(int value READ value NOTIFY changed)
            Q_PROPERTY(bool muted READ muted NOTIFY changed)
            Q_PROPERTY(QString error READ error NOTIFY changed)

        public:

            explicit Manager(QObject* parent = nullptr);

            ~Manager() override;

            bool available() const;

            int value() const;

            bool muted() const;

            QString error() const;

            Q_INVOKABLE void setValue(int percentage);

        signals:
            void changed();

        private:

            void refresh();

            void write();

            QProcess monitor;
            QProcess reader;
            QProcess writer;
            QTimer updates;
            QTimer debounce;
            bool supported = false;
            bool silent = false;
            bool refreshPending = false;
            int percentage = 0;
            int requested = -1;
            QString failure;
    };
}
