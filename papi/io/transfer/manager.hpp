#ifndef PEDRO_PAPI_IO_TRANSFER_MANAGER_HPP
#define PEDRO_PAPI_IO_TRANSFER_MANAGER_HPP

#include <QObject>
#include <QUrl>
#include <QVariantList>

#include <memory>

struct _GCancellable;

namespace Pedro::Papi::Io::Transfer {

    class Manager final : public QObject {
            Q_OBJECT
            Q_PROPERTY(bool busy READ busy NOTIFY changed)
            Q_PROPERTY(bool cancelled READ cancelled NOTIFY changed)
            Q_PROPERTY(double progress READ progress NOTIFY changed)
            Q_PROPERTY(QString currentFile READ currentFile NOTIFY changed)
            Q_PROPERTY(QString error READ error NOTIFY changed)
            Q_PROPERTY(QVariantList completed READ completed NOTIFY changed)

        public:

            explicit Manager(QObject* parent = nullptr);

            ~Manager() override;

            bool busy() const;

            bool cancelled() const;

            double progress() const;

            QString currentFile() const;

            QString error() const;

            QVariantList completed() const;

            void setCurrentFile(const QString& name);

            Q_INVOKABLE void updateProgress(double value);

            Q_INVOKABLE void cancel();

            Q_INVOKABLE void dismissError();

            Q_INVOKABLE bool canMove(const QVariantList& urls, const QUrl& destination) const;

            Q_INVOKABLE void move(const QVariantList& urls, const QUrl& destination);

            void transfer(const QVariantList& urls, const QUrl& destination, bool cut);

        signals:
            void changed();

            void failed(const QString& message);

            void finished(const QString& error);

        private:

            bool transferring = false;
            bool wasCancelled = false;
            double fraction = 0;
            QString current;
            QString failure;
            QVariantList successes;
            std::shared_ptr<_GCancellable> cancellation;
    };

}

#endif
