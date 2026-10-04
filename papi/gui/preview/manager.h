#ifndef PEDRO_PAPI_GUI_PREVIEW_MANAGER_H
#define PEDRO_PAPI_GUI_PREVIEW_MANAGER_H

#include <pedro/papi/gui/preview/registry.h>

#include <QMutex>
#include <QVariantList>

namespace Pedro::Papi::Gui::Preview {

    class Manager final : public QObject {
            Q_OBJECT
            Q_PROPERTY(QUrl source READ source NOTIFY changed)
            Q_PROPERTY(QString name READ name NOTIFY changed)
            Q_PROPERTY(QString mimeType READ mimeType NOTIFY changed)
            Q_PROPERTY(QString kind READ kind NOTIFY changed)
            Q_PROPERTY(QString error READ error NOTIFY changed)
            Q_PROPERTY(QString text READ text NOTIFY changed)
            Q_PROPERTY(bool textTruncated READ textTruncated NOTIFY changed)
            Q_PROPERTY(bool active READ active NOTIFY changed)
            Q_PROPERTY(bool busy READ busy NOTIFY changed)
            Q_PROPERTY(int page READ page NOTIFY changed)
            Q_PROPERTY(int pageCount READ pageCount NOTIFY changed)
            Q_PROPERTY(qint64 position READ position NOTIFY changed)
            Q_PROPERTY(qint64 duration READ duration NOTIFY changed)
            Q_PROPERTY(bool playing READ playing NOTIFY changed)
            Q_PROPERTY(bool seekable READ seekable NOTIFY changed)
            Q_PROPERTY(qreal volume READ volume WRITE setVolume NOTIFY changed)
            Q_PROPERTY(bool muted READ muted WRITE setMuted NOTIFY changed)
            Q_PROPERTY(bool canNext READ canNext NOTIFY changed)
            Q_PROPERTY(bool canPrevious READ canPrevious NOTIFY changed)
            Q_PROPERTY(quint64 revision READ revision NOTIFY frameChanged)
            Q_PROPERTY(QSize frameSize READ frameSize NOTIFY frameChanged)

        public:

            explicit Manager(QObject* parent = nullptr);

            ~Manager() override;

            QUrl source() const;

            QString name() const;

            QString mimeType() const;

            QString kind() const;

            QString error() const;

            QString text() const;

            bool textTruncated() const;

            bool active() const;

            bool busy() const;

            int page() const;

            int pageCount() const;

            qint64 position() const;

            qint64 duration() const;

            bool playing() const;

            bool seekable() const;

            qreal volume() const;

            bool muted() const;

            bool canNext() const;

            bool canPrevious() const;

            quint64 revision() const;

            QSize frameSize() const;

            // Thread-safe surface consumed by Qt image providers, without GUI dependencies.
            QImage frame() const;

            // Register additional MIME providers without changing the QML interface.
            void registerProvider(QStringList types, Registry::Factory factory);

            Q_INVOKABLE void open(const QUrl& source, const QVariantList& siblings = {});

            Q_INVOKABLE void close();

            Q_INVOKABLE void next();

            Q_INVOKABLE void previous();

            Q_INVOKABLE void setPage(int page);

            Q_INVOKABLE void togglePlayback();

            Q_INVOKABLE void seek(qint64 position);

            void setVolume(qreal volume);

            void setMuted(bool muted);

        signals:
            void changed();

            void frameChanged();

            void opened();

        private:

            void select(const QUrl& source);

            void update();

            Registry registry;

            std::unique_ptr<Provider> provider;

            State current;

            QUrl currentSource;

            QString currentName;

            QString currentMime;

            QList<QUrl> playlist;

            int index = -1;

            quint64 generation = 0;

            quint64 frameRevision = 0;

            mutable QMutex frameMutex;

            QImage currentFrame;
    };

}

#endif
