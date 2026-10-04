#include <pedro/papi/gui/preview/text/provider.h>

#include <QCoreApplication>
#include <QFile>
#include <QFileInfo>
#include <QStringDecoder>
#include <QStringEncoder>
#include <QSaveFile>

namespace Pedro::Papi::Gui::Preview::Text {

    Provider::Provider() : Preview::Provider(QStringLiteral("text")) {
    }

    void Provider::open(const QUrl& source) {

        currentSource = source;

        run([source] {
            State result;
            result.kind = QStringLiteral("text");
            QFile file(source.toLocalFile());

            if (!file.open(QIODevice::ReadOnly)) {
                result.error = file.errorString();
                return result;
            }

            constexpr qint64 maximumBytes = 128 * 1024;
            auto bytes = file.read(maximumBytes + 1);
            const bool truncated = bytes.size() > maximumBytes;
            bytes.truncate(maximumBytes);
            const auto encoding = QStringConverter::encodingForData(bytes).value_or(QStringConverter::Utf8);
            QStringDecoder decoder(encoding);
            result.text = decoder(bytes);

            if (result.text.contains(QChar::Null) || (decoder.hasError() && !truncated)) {
                result.error = QStringLiteral("This file does not contain supported plain text.");
                result.text.clear();
                return result;
            }

            result.textTruncated = truncated;
            auto lines = result.text.split('\n');

            if (lines.size() > 2000) {
                lines = lines.mid(0, 2000);
                result.textTruncated = true;
            }

            for (auto& line : lines) {
                if (line.size() > 4096) {
                    line.truncate(4096);
                    line.append(QChar(0x2026));
                    result.textTruncated = true;
                }
            }

            result.text = lines.join('\n');
            result.originalText = bytes;
            result.crlfText = result.text.contains(QStringLiteral("\r\n"));
            result.editable = !result.textTruncated && QFileInfo(file).isWritable();

            return result;
        });
    }

    bool Provider::saveText(const QString& text) {

        if (!current.editable || current.busy) {
            return false;
        }

        QFile original(currentSource.toLocalFile());
        if (!original.open(QIODevice::ReadOnly) || original.read(128 * 1024 + 1) != current.originalText) {
            current.saveError = QCoreApplication::translate("Pedro", "preview.edit.conflict");
            emit changed();
            return false;
        }
        original.close();

        const auto encoding = QStringConverter::encodingForData(current.originalText).value_or(QStringConverter::Utf8);
        QStringEncoder withBom(encoding, QStringConverter::Flag::WriteBom);
        QStringEncoder withoutBom(encoding);
        const QByteArray sample = withBom(QStringLiteral("x"));
        const QByteArray plainSample = withoutBom(QStringLiteral("x"));
        const QByteArray marker = sample.left(sample.size() - plainSample.size());
        const bool hadBom = !marker.isEmpty() && current.originalText.startsWith(marker);
        QStringEncoder encoder(encoding, hadBom ? QStringConverter::Flag::WriteBom : QStringConverter::Flag::Default);
        QString contents = text;
        if (current.crlfText && !contents.contains("\r\n")) {
            contents.replace("\n", "\r\n");
        }
        const QByteArray bytes = encoder(contents);
        QSaveFile output(currentSource.toLocalFile());
        if (bytes.size() > 128 * 1024 || encoder.hasError()) {
            current.saveError = QCoreApplication::translate("Pedro", "preview.edit.limit");
        } else if (!output.open(QIODevice::WriteOnly) || output.write(bytes) != bytes.size() || !output.commit()) {
            current.saveError = output.errorString();
        } else {
            current.originalText = bytes;
            current.text = text;
            current.saveError.clear();
            emit changed();
            return true;
        }
        emit changed();
        return false;
    }

}
