#include <pedro/papi/gui/preview/text/provider.h>

#include <QFile>
#include <QStringDecoder>

namespace Pedro::Papi::Gui::Preview::Text {

    Provider::Provider() : Preview::Provider(QStringLiteral("text")) {
    }

    void Provider::open(const QUrl& source) {

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

            return result;
        });
    }

}
