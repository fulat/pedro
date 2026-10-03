#pragma once

#include <QObject>
#include <QHash>
#include <QVariantList>

struct _GSettings;

namespace Pedro::Papi::Display::Keyboard {
    class Manager final : public QObject {
            Q_OBJECT
            Q_PROPERTY(QVariantList layouts READ layouts NOTIFY changed)

        public:

            explicit Manager(QObject* parent = nullptr);

            ~Manager() override;

            QVariantList layouts() const;

        signals:
            void changed();

        private:

            _GSettings* settings = nullptr;
            QHash<QString, QString> names;
    };
}
