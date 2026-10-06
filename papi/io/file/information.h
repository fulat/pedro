#ifndef PEDRO_PAPI_IO_FILE_INFORMATION_H
#define PEDRO_PAPI_IO_FILE_INFORMATION_H

#include <pedro/papi/io/file/watch.h>

#include <QObject>
#include <QVariantMap>

#include <memory>

struct _GCancellable;

namespace Pedro::Papi::Io::File {

    class Information : public QObject {
            Q_OBJECT
            Q_PROPERTY(QUrl source READ source WRITE setSource NOTIFY changed)
            Q_PROPERTY(QVariantMap data READ data NOTIFY changed)
            Q_PROPERTY(bool loading READ loading NOTIFY changed)
            Q_PROPERTY(QString error READ error NOTIFY changed)

        public:

            explicit Information(QObject* parent = nullptr);

            ~Information() override;

            QUrl source() const;

            void setSource(const QUrl& source);

            QVariantMap data() const;

            bool loading() const;

            QString error() const;

            Q_INVOKABLE void refresh();

        signals:
            void changed();

        private:

            Watch watch;
            QUrl currentSource;
            QVariantMap values;
            QString failure;
            bool busy = false;
            quint64 generation = 0;
            std::shared_ptr<_GCancellable> cancellation;
    };

}

#endif
