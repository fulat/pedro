#pragma once

#include <QObject>
#include <QFileSystemWatcher>
#include <QTimer>
#include <QString>

namespace Pedro::Papi::Config {

    class Store : public QObject {
            Q_OBJECT

        public:

            explicit Store(QObject* parent = nullptr);

            static QString defaults();

            static QString path(const QString& name);

            static QString value(const QString& name, const QString& section, const QString& key);

        signals:
            void changed();

        private:

            void watch();

            QFileSystemWatcher watcher;

            QTimer debounce;
    };

}
