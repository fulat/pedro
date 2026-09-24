#pragma once

class QQuickWindow;

namespace Pedro::Gui::Render {

    class Info {

        public:

            static void attach(QQuickWindow& window);
    };

}
