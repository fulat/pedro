#ifndef PEDRO_PAPI_GUI_PREVIEW_PROVIDER_H
#define PEDRO_PAPI_GUI_PREVIEW_PROVIDER_H

#include <pedro/papi/gui/preview/state.h>

#include <QObject>
#include <QUrl>

#include <functional>

namespace Pedro::Papi::Gui::Preview {

    class Provider : public QObject {
            Q_OBJECT

        public:

            explicit Provider(QString kind, QObject* parent = nullptr);

            ~Provider() override;

            const State& state() const;

            virtual void open(const QUrl& source) = 0;

            virtual void close();

            virtual bool saveText(const QString& text);

            virtual void setPage(int page);

            virtual void togglePlayback();

            virtual void seek(qint64 position);

            virtual void setVolume(qreal volume);

            virtual void setMuted(bool muted);

        signals:
            void changed();

        protected:

            void run(std::function<State()> work);

            State current;

        private:

            quint64 generation = 0;
    };

}

#endif
