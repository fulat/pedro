#ifndef PEDRO_PAPI_IO_TAG_EVENT_H
#define PEDRO_PAPI_IO_TAG_EVENT_H
#include <QObject>

namespace Pedro::Papi::Io::Tag {

    class Event : public QObject {
            Q_OBJECT

        public:

            using QObject::QObject;
            static Event* instance();

        signals:
            void changed();
    };
}
#endif
