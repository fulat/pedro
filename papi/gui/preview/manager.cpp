#include <pedro/papi/gui/preview/manager.h>

#include <QFileInfo>
#include <QFutureWatcher>
#include <QMimeDatabase>
#include <QMutexLocker>
#include <QtConcurrentRun>

#include <algorithm>
#include <utility>

namespace Pedro::Papi::Gui::Preview {

    namespace {

        QUrl normalize(const QUrl& source) {

            return source.isRelative() ? QUrl::fromLocalFile(QFileInfo(source.toString()).absoluteFilePath()) : source;
        }

        struct Info {
                QString name;
                QString error;
                QMimeType mime;
        };

    }

    Manager::Manager(QObject* parent) : QObject(parent) {
    }

    Manager::~Manager() {
        close();
    }

    QUrl Manager::source() const {
        return currentSource;
    }

    QString Manager::name() const {
        return currentName;
    }

    QString Manager::mimeType() const {
        return currentMime;
    }

    QString Manager::kind() const {
        return current.kind;
    }

    QString Manager::error() const {
        return current.error;
    }

    QString Manager::text() const {
        return current.text;
    }

    bool Manager::editable() const {
        return current.editable;
    }

    QString Manager::saveError() const {
        return current.saveError;
    }

    bool Manager::saveText(const QString& text) {
        return provider && provider->saveText(text);
    }

    bool Manager::textTruncated() const {
        return current.textTruncated;
    }

    bool Manager::active() const {
        return !currentSource.isEmpty();
    }

    bool Manager::busy() const {
        return current.busy;
    }

    int Manager::page() const {
        return current.page;
    }

    int Manager::pageCount() const {
        return current.pageCount;
    }

    qint64 Manager::position() const {
        return current.position;
    }

    qint64 Manager::duration() const {
        return current.duration;
    }

    bool Manager::playing() const {
        return current.playing;
    }

    bool Manager::seekable() const {
        return current.seekable;
    }

    qreal Manager::volume() const {
        return current.volume;
    }

    bool Manager::muted() const {
        return current.muted;
    }

    bool Manager::canNext() const {
        return index >= 0 && index + 1 < playlist.size();
    }

    bool Manager::canPrevious() const {
        return index > 0;
    }

    quint64 Manager::revision() const {
        return frameRevision;
    }

    QSize Manager::frameSize() const {
        return frame().size();
    }

    QImage Manager::frame() const {

        QMutexLocker lock(&frameMutex);
        return currentFrame;
    }

    void Manager::registerProvider(QStringList types, Registry::Factory factory) {

        registry.add(std::move(types), std::move(factory));
    }

    void Manager::open(const QUrl& source, const QVariantList& siblings) {

        if (source.isEmpty()) {
            return;
        }

        playlist.clear();

        for (const auto& value : siblings) {
            if (value.toUrl().isEmpty()) {
                continue;
            }

            const auto url = normalize(value.toUrl());

            if (!url.isEmpty() && !playlist.contains(url)) {
                playlist.append(url);
            }
        }

        const auto url = normalize(source);

        if (!playlist.contains(url)) {
            playlist.prepend(url);
        }

        index = playlist.indexOf(url);
        select(url);
        emit opened();
    }

    void Manager::select(const QUrl& source) {

        const auto request = ++generation;
        const auto savedVolume = current.volume;
        const auto savedMuted = current.muted;

        if (provider) {
            provider->close();
            provider.reset();
        }

        current = State{};
        current.volume = savedVolume;
        current.muted = savedMuted;
        current.busy = true;
        currentSource = source;
        currentName = source.fileName();
        currentMime.clear();
        update();

        auto* watcher = new QFutureWatcher<Info>(this);
        connect(watcher, &QFutureWatcher<Info>::finished, this, [this, watcher, request, source] {
            const auto info = watcher->result();
            watcher->deleteLater();

            if (request != generation) {
                return;
            }

            currentName = info.name;
            currentMime = info.mime.name();

            if (!info.error.isEmpty()) {
                current.error = info.error;
                current.kind = QStringLiteral("unsupported");
                current.busy = false;
                update();
                return;
            }

            provider = registry.create(info.mime);
            provider->setVolume(current.volume);
            provider->setMuted(current.muted);
            connect(provider.get(), &Provider::changed, this, &Manager::update);
            provider->open(source);
        });
        watcher->setFuture(QtConcurrent::run([source] {
            Info result;
            result.name = source.fileName();

            if (!source.isLocalFile()) {
                result.error = QStringLiteral("Preview currently requires a local file.");
                return result;
            }

            const QFileInfo file(source.toLocalFile());
            result.name = file.fileName();

            if (!file.isFile() || !file.isReadable()) {
                result.error = QStringLiteral("This file is missing or cannot be read.");
                return result;
            }

            QMimeDatabase database;
            result.mime = file.size() == 0 ? database.mimeTypeForName(QStringLiteral("text/plain")) : database.mimeTypeForFile(file, QMimeDatabase::MatchDefault);
            if (result.mime.name() == QStringLiteral("application/octet-stream")) {
                // Qt content sniffing handles readable text without relying on a filename suffix.
                const auto content = database.mimeTypeForFile(file, QMimeDatabase::MatchContent);
                if (content.inherits(QStringLiteral("text/plain")))
                    result.mime = content;
            }
            return result;
        }));
    }

    void Manager::close() {

        ++generation;

        if (provider) {
            provider->close();
            provider.reset();
        }

        const auto savedVolume = current.volume;
        const auto savedMuted = current.muted;
        current = State{};
        current.volume = savedVolume;
        current.muted = savedMuted;
        currentSource.clear();
        currentName.clear();
        currentMime.clear();
        playlist.clear();
        index = -1;
        update();
    }

    void Manager::next() {

        if (canNext()) {
            select(playlist.at(++index));
        }
    }

    void Manager::previous() {

        if (canPrevious()) {
            select(playlist.at(--index));
        }
    }

    void Manager::setPage(int page) {

        if (provider) {
            provider->setPage(page);
        }
    }

    void Manager::togglePlayback() {

        if (provider) {
            provider->togglePlayback();
        }
    }

    void Manager::seek(qint64 position) {

        if (provider) {
            provider->seek(position);
        }
    }

    void Manager::setVolume(qreal volume) {

        current.volume = std::clamp(volume, 0.0, 1.0);

        if (provider) {
            provider->setVolume(current.volume);
        } else {
            emit changed();
        }
    }

    void Manager::setMuted(bool muted) {

        current.muted = muted;

        if (provider) {
            provider->setMuted(muted);
        } else {
            emit changed();
        }
    }

    void Manager::update() {

        if (provider) {
            current = provider->state();
        }

        bool newFrame = false;
        {
            QMutexLocker lock(&frameMutex);
            newFrame = currentFrame.cacheKey() != current.frame.cacheKey();
            currentFrame = current.frame;
        }

        if (newFrame) {
            ++frameRevision;
            emit frameChanged();
        }

        emit changed();
    }

}
