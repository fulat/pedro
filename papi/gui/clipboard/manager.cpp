#include <pedro/papi/gui/clipboard/manager.hpp>

#include <QClipboard>
#include <QGuiApplication>
#include <QMimeData>
#include <QFileInfo>

#include <algorithm>
#include <memory>

namespace Pedro::Papi::Gui::Clipboard {

    namespace {

        QList<QUrl> files() {
            const auto* mime = QGuiApplication::clipboard()->mimeData();
            if (!mime) {
                return {};
            }
            if (mime->hasFormat("x-special/gnome-copied-files")) {
                QList<QUrl> urls;
                const auto lines = mime->data("x-special/gnome-copied-files").split('\n');
                for (int index = 1; index < lines.size(); ++index) {
                    const QUrl url(QString::fromUtf8(lines.at(index)));
                    if (url.isValid() && !url.isEmpty()) {
                        urls.append(url);
                    }
                }
                return urls;
            }
            return mime->urls();
        }

    }

    Manager::Manager(QObject* parent) : QObject(parent) {
        connect(&transfer, &Pedro::Papi::Io::Transfer::Manager::changed, this, &Manager::changed);
        connect(&transfer, &Pedro::Papi::Io::Transfer::Manager::failed, this, &Manager::failed);
        connect(QGuiApplication::clipboard(), &QClipboard::dataChanged, this, &Manager::changed);
    }

    bool Manager::canPaste() const {
        const auto urls = files();
        const auto* mime = QGuiApplication::clipboard()->mimeData();
        const bool cut = mime && mime->data("x-special/gnome-copied-files").startsWith("cut\n");
        return !transfer.busy() && !urls.isEmpty() && std::all_of(urls.cbegin(), urls.cend(), [cut](const auto& url) { return (!cut && url.scheme() == "trash") || (url.isLocalFile() && QFileInfo::exists(url.toLocalFile())); });
    }

    bool Manager::busy() const {
        return transfer.busy();
    }

    void Manager::copy(const QVariantList& values, bool cut) {
        QList<QUrl> urls;
        QByteArray data = cut ? "cut" : "copy";
        for (const auto& value : values) {
            const auto url = value.toUrl();
            if (url.isLocalFile() || (!cut && url.scheme() == "trash")) {
                urls.append(url);
                data += '\n' + url.toEncoded();
            }
        }
        if (urls.isEmpty()) {
            return;
        }
        auto* mime = new QMimeData;
        mime->setUrls(urls);
        mime->setData("x-special/gnome-copied-files", data);
        QGuiApplication::clipboard()->setMimeData(mime);
    }

    void Manager::paste(const QUrl& requestedDestination) {
        const auto destination = requestedDestination.scheme().isEmpty() ? QUrl::fromLocalFile(requestedDestination.toString()) : requestedDestination;
        if (!canPaste() || !destination.isLocalFile() || !QFileInfo(destination.toLocalFile()).isDir()) {
            return;
        }
        const auto urls = files();
        const auto* mime = QGuiApplication::clipboard()->mimeData();
        const auto original = mime->data("x-special/gnome-copied-files");
        const bool cut = original.startsWith("cut\n");
        auto connection = std::make_shared<QMetaObject::Connection>();
        *connection = connect(&transfer, &Pedro::Papi::Io::Transfer::Manager::finished, this, [this, cut, original, urls, connection](const QString& error) {
            disconnect(*connection);
            if (error.isEmpty() && cut && files() == urls && QGuiApplication::clipboard()->mimeData()->data("x-special/gnome-copied-files") == original) {
                QGuiApplication::clipboard()->clear();
            }
        });
        QVariantList values;
        for (const auto& url : urls) {
            values.append(url);
        }
        transfer.transfer(values, destination, cut);
    }

}
