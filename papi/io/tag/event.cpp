#include <pedro/papi/io/tag/event.h>

#include <QCoreApplication>

namespace Pedro::Papi::Io::Tag {

    Event* Event::instance() {
        static auto* event = new Event(QCoreApplication::instance());
        return event;
    }
}
