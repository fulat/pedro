#ifndef PEDRO_PAPI_GUI_APPEARANCE_GLASS_MANAGER_H
#define PEDRO_PAPI_GUI_APPEARANCE_GLASS_MANAGER_H

#include <QObject>
#include <QStringList>

namespace Pedro::Papi::Gui::Appearance::Glass {

    class Manager final : public QObject {
            Q_OBJECT

        public:

            explicit Manager(QObject* parent = nullptr);

            Q_INVOKABLE void registerTitle(const QString& title);

        private:

            void sendTitle(const QString& title);

            QStringList titles;
    };
}

#endif
