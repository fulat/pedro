#pragma once

#include <QObject>
#include <QUrl>
#include <QVariantList>

#include <memory>

namespace Pedro::Papi::Io::Content {

    class Applications : public QObject {
            Q_OBJECT
            Q_PROPERTY(QUrl source READ source WRITE setSource NOTIFY changed)
            Q_PROPERTY(QVariantList applications READ applications NOTIFY changed)
            Q_PROPERTY(bool loading READ loading NOTIFY changed)
            Q_PROPERTY(QString error READ error NOTIFY changed)

        public:

            explicit Applications(QObject* parent = nullptr);

            ~Applications() override;

            QUrl source() const;

            void setSource(const QUrl& source);

            QVariantList applications() const;

            bool loading() const;

            QString error() const;

            Q_INVOKABLE bool launch(const QString& id);

            Q_INVOKABLE void refresh();

        signals:
            void changed();

            void launched();

            void failed(const QString& message);

        private:

            struct State;

            std::unique_ptr<State> state;
    };

}
