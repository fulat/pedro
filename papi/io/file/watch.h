#ifndef PEDRO_PAPI_IO_FILE_WATCH_H
#define PEDRO_PAPI_IO_FILE_WATCH_H

#include <QObject>
#include <QUrl>

#include <memory>

namespace Pedro::Papi::Io::File {

    // GIO notifications plus a retained Linux file handle follow external moves
    // without scanning directories or depending on the consumer's file view.
    class Watch final : public QObject {
            Q_OBJECT

        public:

            explicit Watch(QObject* parent = nullptr);

            ~Watch() override;

            void open(const QUrl& source);

            void close();

            void refresh();

            QUrl source() const;

            bool available() const;

        signals:
            void relocated(const QUrl& source, const QUrl& destination);

            void changed();

        private:

            struct Data;

            void monitor();

            void follow(const QUrl& source, const QUrl& destination);

            std::unique_ptr<Data> data;
    };

}

#endif
