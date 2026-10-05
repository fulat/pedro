#include <pedro/papi/gui/preview/provider.h>

#include <QFutureWatcher>
#include <QtConcurrentRun>

#include <utility>

namespace Pedro::Papi::Gui::Preview {

    Provider::Provider(QString kind, QObject* parent) : QObject(parent) {

        current.kind = std::move(kind);
    }

    Provider::~Provider() = default;

    const State& Provider::state() const {
        return current;
    }

    void Provider::close() {

        ++generation;
        current.busy = false;
        current.playing = false;
    }

    void Provider::relocate(const QUrl&) {
    }

    bool Provider::saveText(const QString&) {

        return false;
    }

    void Provider::setPage(int) {
    }

    void Provider::togglePlayback() {
    }

    void Provider::seek(qint64) {
    }

    void Provider::setVolume(qreal volume) {

        current.volume = volume;
        emit changed();
    }

    void Provider::setMuted(bool muted) {

        current.muted = muted;
        emit changed();
    }

    void Provider::run(std::function<State()> work) {

        const auto request = ++generation;
        current.busy = true;
        current.error.clear();
        emit changed();

        auto* watcher = new QFutureWatcher<State>(this);
        connect(watcher, &QFutureWatcher<State>::finished, this, [this, watcher, request] {
            const auto result = watcher->result();
            watcher->deleteLater();

            if (request != generation) {
                return;
            }

            const auto savedVolume = current.volume;
            const auto savedMuted = current.muted;
            current = result;
            current.volume = savedVolume;
            current.muted = savedMuted;
            current.busy = false;
            emit changed();
        });
        watcher->setFuture(QtConcurrent::run(std::move(work)));
    }

}
