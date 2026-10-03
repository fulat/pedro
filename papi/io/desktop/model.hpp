#pragma once

#include <QAbstractListModel>
#include <QString>
#include <QVariantMap>

#include <memory>

namespace Pedro::Papi::Io::Desktop {

    class Model final : public QAbstractListModel {
            Q_OBJECT
            Q_PROPERTY(QString directory READ directory CONSTANT)
            Q_PROPERTY(QString error READ error NOTIFY errorChanged)
            Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
            Q_PROPERTY(QString organization READ organization NOTIFY organizationChanged)
            Q_PROPERTY(bool keepAligned READ keepAligned NOTIFY organizationChanged)
            Q_PROPERTY(QVariantList groups READ groups NOTIFY groupsChanged)
            Q_PROPERTY(QString sortKey READ sortKey NOTIFY sortChanged)

        public:

            explicit Model(QObject* parent = nullptr);

            ~Model() override;

            int rowCount(const QModelIndex& parent = {}) const override;

            QVariant data(const QModelIndex& index, int role) const override;

            QHash<int, QByteArray> roleNames() const override;

            QString directory() const;

            QString error() const;

            bool loading() const;

            QString organization() const;

            bool keepAligned() const;

            QVariantList groups() const;

            QString sortKey() const;

            Q_INVOKABLE void sort(const QString& key);

            Q_INVOKABLE void setOrganization(const QString& mode);

            Q_INVOKABLE void setKeepAligned(bool enabled);

            Q_INVOKABLE void createFolder(const QString& name);

            Q_INVOKABLE void createFile(const QString& name);

            Q_INVOKABLE void renameEntry(const QString& id, const QString& name);

            Q_INVOKABLE void savePosition(const QString& id, double x, double y, bool manual = false);

        signals:
            void errorChanged();

            void organizationChanged();

            void groupsChanged();

            void sortChanged();

            void sortRequested();

            void sortRestored();

            void entryCreated(const QString& id);

            void entryRenamed(const QString& id);

            void operationFailed(const QString& message);

            void loadingChanged();

        private:

            struct State;

            void apply(const QString& uri, const QVariantMap& entry);

            void setError(const QString& error);

            void reorder();

            std::unique_ptr<State> state;
    };

}
