#ifndef PEDRO_PAPI_IO_TAG_MODEL_H
#define PEDRO_PAPI_IO_TAG_MODEL_H

#include <QAbstractListModel>
#include <QVariantList>
#include <QUrl>
#include <QSet>

namespace Pedro::Papi::Io::File {
    class Watch;
}

namespace Pedro::Papi::Io::Tag {

    class Model : public QAbstractListModel {
            Q_OBJECT
            Q_PROPERTY(QVariantList tags READ tags NOTIFY changed)
            Q_PROPERTY(QString error READ error NOTIFY changed)
            Q_PROPERTY(bool busy READ busy NOTIFY changed)
            Q_PROPERTY(int revision READ revision NOTIFY changed)

        public:

            explicit Model(QObject* parent = nullptr);

            int rowCount(const QModelIndex& parent = {}) const override;
            QVariant data(const QModelIndex& index, int role) const override;
            QHash<int, QByteArray> roleNames() const override;
            QVariantList tags() const;
            QString error() const;
            bool busy() const;
            int revision() const;

            Q_INVOKABLE QString create(const QString& name, const QString& color);
            Q_INVOKABLE bool rename(const QString& id, const QString& name);
            Q_INVOKABLE bool setColor(const QString& id, const QString& color);
            Q_INVOKABLE bool remove(const QString& id);
            Q_INVOKABLE QVariantMap definition(const QString& id) const;
            Q_INVOKABLE QStringList fileTags(const QUrl& source) const;
            Q_INVOKABLE void assign(const QUrl& source, const QString& id, bool enabled);

        signals:
            void changed();
            void fileTagsChanged(const QUrl& source);

        private:

            QHash<QString, Pedro::Papi::Io::File::Watch*> monitors;
            QVariantList values;
            QString failure;
            QSet<QString> pending;
            int version = 0;
            void refresh();
            bool validName(const QString& name, const QString& except = {});
    };
}
#endif
