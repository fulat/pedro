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
                if (lines.isEmpty() || (lines.first() != "copy" && lines.first() != "cut")) {
                    return {};
                }
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
        connect(QGuiApplication::clipboard(), &QClipboard::dataChanged, this, [this] {
            refreshCutFiles();
            emit changed();
        });
        refreshCutFiles();
    }

    bool Manager::canPaste() const {
        const auto urls = files();
        const auto* mime = QGuiApplication::clipboard()->mimeData();
        const bool cut = mime && mime->data("x-special/gnome-copied-files").startsWith("cut\n");
        return !transfer.busy() && !urls.isEmpty() && std::all_of(urls.cbegin(), urls.cend(), [cut](const auto& url) { return (!cut && url.scheme() == "trash") || url.isLocalFile(); });
    }

    bool Manager::canPasteInto(const QUrl& requestedDestination) const {
        const auto destination = requestedDestination.scheme().isEmpty() ? QUrl::fromLocalFile(requestedDestination.toString()) : requestedDestination;
        const QFileInfo target(destination.toLocalFile());
        if (!canPaste() || !destination.isLocalFile() || !target.isDir()) {
            return false;
        }
        const auto targetPath = target.canonicalFilePath();
        for (const auto& value : pendingCutFiles) {
            const QFileInfo source(value.toUrl().toLocalFile());
            if (QFileInfo(source.absolutePath()).canonicalFilePath() == targetPath) {
                return false;
            }
        }
        return true;
    }

    void Manager::refreshCutFiles() {
        const auto* mime = QGuiApplication::clipboard()->mimeData();
        pendingCutFiles.clear();
        if (!mime || !mime->data("x-special/gnome-copied-files").startsWith("cut\n")) {
            return;
        }
        for (const auto& url : files()) {
            if (url.isLocalFile()) {
                pendingCutFiles.append(url);
            }
        }
    }

    QVariantList Manager::cutFiles() const {
        return pendingCutFiles;
    }

    bool Manager::isCut(const QUrl& url) const {
        if (!url.isLocalFile()) {
            return false;
        }
        const auto normalized = url.adjusted(QUrl::NormalizePathSegments | QUrl::StripTrailingSlash);
        for (const auto& value : cutFiles()) {
            if (value.toUrl().adjusted(QUrl::NormalizePathSegments | QUrl::StripTrailingSlash) == normalized) {
                return true;
            }
        }
        return false;
    }

    bool Manager::canCut(const QVariantList& urls) const {
        return std::any_of(urls.cbegin(), urls.cend(), [this](const auto& value) {
            const auto url = value.toUrl();
            return url.isLocalFile() && !isCut(url);
        });
    }

    bool Manager::busy() const {
        return transfer.busy();
    }

    Pedro::Papi::Io::Transfer::Manager* Manager::operation() {
        return &transfer;
    }

    void Manager::copy(const QVariantList& values, bool cut) {
        if (cut && !canCut(values)) {
            return;
        }
        setFiles(values, cut);
    }

    void Manager::setFiles(const QVariantList& values, bool cut) {
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
        if (!canPasteInto(destination)) {
            return;
        }
        const auto urls = files();
        const auto* mime = QGuiApplication::clipboard()->mimeData();
        const auto original = mime->data("x-special/gnome-copied-files");
        const bool cut = original.startsWith("cut\n");
        auto connection = std::make_shared<QMetaObject::Connection>();
        *connection = connect(&transfer, &Pedro::Papi::Io::Transfer::Manager::finished, this, [this, cut, original, urls, connection](const QString& error) {
            disconnect(*connection);
            const auto* current = QGuiApplication::clipboard()->mimeData();
            if (cut && files() == urls && current && current->data("x-special/gnome-copied-files") == original) {
                QVariantList remaining;
                for (const auto& url : urls) {
                    if (!transfer.completed().contains(QVariant(url))) {
                        remaining.append(url);
                    }
                }
                if (remaining.isEmpty()) {
                    QGuiApplication::clipboard()->clear();
                } else {
                    setFiles(remaining, true);
                }
            }
        });
        QVariantList values;
        for (const auto& url : urls) {
            values.append(url);
        }
        transfer.transfer(values, destination, cut);
    }

}
