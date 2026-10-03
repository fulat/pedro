#pragma once

#include <QObject>
#include <QUrl>
#include <QVariantList>

namespace Pedro::Papi::Io::Transfer {

    class Manager final : public QObject {
            Q_OBJECT
            Q_PROPERTY(bool busy READ busy NOTIFY changed)

        public:

            explicit Manager(QObject* parent = nullptr);

            bool busy() const;

            Q_INVOKABLE bool canMove(const QVariantList& urls, const QUrl& destination) const;

            Q_INVOKABLE void move(const QVariantList& urls, const QUrl& destination);

            void transfer(const QVariantList& urls, const QUrl& destination, bool cut);

        signals:
            void changed();

            void failed(const QString& message);

            void finished(const QString& error);

        private:

            bool transferring = false;
    };

}
