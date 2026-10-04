#ifndef PEDRO_PAPI_GUI_PREVIEW_STATE_H
#define PEDRO_PAPI_GUI_PREVIEW_STATE_H

#include <QImage>
#include <QString>

namespace Pedro::Papi::Gui::Preview {

    struct State {
            QString kind;
            QString error;
            QString text;
            bool textTruncated = false;
            QImage frame;
            bool busy = false;
            int page = 0;
            int pageCount = 0;
            qint64 position = 0;
            qint64 duration = 0;
            bool playing = false;
            bool seekable = false;
            qreal volume = 0.8;
            bool muted = false;
    };

}

#endif
