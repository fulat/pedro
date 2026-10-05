#ifndef PEDRO_PAPI_GUI_CLIPBOARD_MANAGER_HPP
#define PEDRO_PAPI_GUI_CLIPBOARD_MANAGER_HPP

#include <pedro/papi/io/transfer/manager.hpp>

#include <QObject>
#include <QUrl>
#include <QVariantList>

namespace Pedro::Papi::Gui::Clipboard {

    class Manager final : public QObject {
            Q_OBJECT
            Q_PROPERTY(bool canPaste READ canPaste NOTIFY changed)
            Q_PROPERTY(bool busy READ busy NOTIFY changed)
            Q_PROPERTY(Pedro::Papi::Io::Transfer::Manager* operation READ operation CONSTANT)

        public:

            explicit Manager(QObject* parent = nullptr);

            bool canPaste() const;

            bool busy() const;

            Pedro::Papi::Io::Transfer::Manager* operation();

            Q_INVOKABLE void copy(const QVariantList& urls, bool cut = false);

            Q_INVOKABLE void paste(const QUrl& destination);

        signals:
            void changed();

            void failed(const QString& message);

        private:

            Pedro::Papi::Io::Transfer::Manager transfer;
    };

}

#endif
