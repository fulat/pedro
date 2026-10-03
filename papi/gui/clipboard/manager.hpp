#pragma once

#include <QObject>
#include <QUrl>
#include <QVariantList>

namespace Pedro::Papi::Gui::Clipboard {

    class Manager final : public QObject {
            Q_OBJECT
            Q_PROPERTY(bool canPaste READ canPaste NOTIFY changed)
            Q_PROPERTY(bool busy READ busy NOTIFY changed)

        public:

            explicit Manager(QObject* parent = nullptr);

            bool canPaste() const;

            bool busy() const;

            Q_INVOKABLE void copy(const QVariantList& urls, bool cut = false);

            Q_INVOKABLE void paste(const QUrl& destination);

        signals:
            void changed();

            void failed(const QString& message);

        private:

            bool transferring = false;
    };

}
