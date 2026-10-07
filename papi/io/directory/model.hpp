#pragma once

#include <QAbstractListModel>
#include <QVariantList>
#include <QStringList>

#include <memory>

namespace Pedro::Papi::Io::Directory {

    class Model : public QAbstractListModel {
            Q_OBJECT
            Q_PROPERTY(QString location READ location NOTIFY locationChanged)
            Q_PROPERTY(QString path READ path NOTIFY locationChanged)
            Q_PROPERTY(QString place READ place NOTIFY locationChanged)
            Q_PROPERTY(QString name READ name NOTIFY locationChanged)
            Q_PROPERTY(bool globalSearch READ globalSearch WRITE setGlobalSearch NOTIFY globalSearchChanged)
            Q_PROPERTY(QString category READ category WRITE setCategory NOTIFY categoryChanged)
            Q_PROPERTY(QStringList categories READ categories NOTIFY contentsChanged)
            Q_PROPERTY(QString search READ search WRITE setSearch NOTIFY searchChanged)
            Q_PROPERTY(int count READ count NOTIFY contentsChanged)
            Q_PROPERTY(QString error READ error NOTIFY contentsChanged)
            Q_PROPERTY(bool loading READ loading NOTIFY contentsChanged)
            Q_PROPERTY(bool canGoBack READ canGoBack NOTIFY locationChanged)
            Q_PROPERTY(bool canGoForward READ canGoForward NOTIFY locationChanged)
            Q_PROPERTY(QAbstractItemModel* entriesModel READ entriesModel CONSTANT)
            Q_PROPERTY(QAbstractItemModel* folderModel READ folderModel CONSTANT)
            Q_PROPERTY(QAbstractItemModel* fileModel READ fileModel CONSTANT)
            Q_PROPERTY(QVariantList folders READ folders NOTIFY contentsChanged)
            Q_PROPERTY(QVariantList files READ files NOTIFY contentsChanged)

        public:

            explicit Model(QObject* parent = nullptr);

            ~Model() override;

            int rowCount(const QModelIndex& parent = {}) const override;

            QVariant data(const QModelIndex& index, int role) const override;

            QHash<int, QByteArray> roleNames() const override;

            QString location() const;

            QString path() const;

            QString place() const;

            QString name() const;

            bool globalSearch() const;

            void setGlobalSearch(bool enabled);

            QString category() const;

            void setCategory(const QString& category);

            QStringList categories() const;

            QString search() const;

            void setSearch(const QString& text);

            int count() const;

            QString error() const;

            bool loading() const;

            bool canGoBack() const;

            bool canGoForward() const;

            QAbstractItemModel* entriesModel();

            Q_INVOKABLE void setSort(const QString& key);

            QAbstractItemModel* folderModel();

            QAbstractItemModel* fileModel();

            QVariantList folders() const;

            QVariantList files() const;

            Q_INVOKABLE void openPlace(const QString& place);

            Q_INVOKABLE void open(const QString& uri);

            Q_INVOKABLE void createFolder(const QString& name);

            Q_INVOKABLE void createFile(const QString& name);

            Q_INVOKABLE void goBack();

            Q_INVOKABLE void goForward();

        signals:
            void globalSearchChanged();

            void categoryChanged();

            void searchChanged();

            void locationChanged();

            void contentsChanged();

        private:

            struct State;

            void navigate(const QString& uri, const QString& place, bool record);

            void create(const QString& name, bool folder);

            void refresh();

            void watch();

            std::unique_ptr<State> state;
    };

}
