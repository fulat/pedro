#pragma once

#include <QObject>
#include <QElapsedTimer>
#include <QTimer>
#include <QVariant>
#include <QRect>

namespace Pedro::Papi::Gui::Capture {
    class Manager final : public QObject {
            Q_OBJECT
            Q_PROPERTY(bool busy READ busy NOTIFY changed)
            Q_PROPERTY(bool visible READ visible NOTIFY changed)
            Q_PROPERTY(bool recording READ recording NOTIFY changed)
            Q_PROPERTY(QString file READ file NOTIFY changed)
            Q_PROPERTY(int elapsed READ elapsed NOTIFY changed)
            Q_PROPERTY(QString error READ error NOTIFY changed)

        public:

            explicit Manager(QObject* parent = nullptr);

            bool busy() const;

            QString error() const;

            bool visible() const;

            bool recording() const;

            QString file() const;

            int elapsed() const;

            Q_INVOKABLE void open();

            Q_INVOKABLE void close();

            Q_INVOKABLE void take(const QRect& area, bool video, bool cursor, int delay);

            Q_INVOKABLE void stop();

        signals:
            void changed();

        private slots:
            void recordingStopped(const QString& error);

        private:

            void finish(const QString& method, const QList<QVariant>& arguments);

            QElapsedTimer clock;
            QTimer ticker;
            int seconds = 0;

            bool shown = false;
            bool running = false;
            QString destination;
            bool pending = false;
            QString failure;
    };
}
