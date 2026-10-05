#include "name.h"

#include <QFontMetricsF>
#include <QTextLayout>
#include <QTextOption>

namespace Pedro::Gui::Backend::Entry {

    QString elideName(const QString& text, const QFont& font, qreal width, int lines, bool file) {
        if (width <= 0 || lines <= 0) {
            return {};
        }
        QTextLayout layout(text, font);
        QTextOption option;
        option.setWrapMode(QTextOption::WrapAtWordBoundaryOrAnywhere);
        layout.setTextOption(option);
        layout.beginLayout();
        int lastStart = 0;
        for (int index = 0; index < lines; ++index) {
            auto line = layout.createLine();
            if (!line.isValid()) {
                layout.endLayout();
                return text;
            }
            line.setLineWidth(width);
            lastStart = line.textStart();
        }
        const bool overflow = layout.createLine().isValid();
        layout.endLayout();
        if (!overflow) {
            return text;
        }
        const QFontMetricsF metrics(font);
        const auto remainder = text.mid(lastStart);
        const auto dot = text.lastIndexOf('.');
        const auto suffix = file && dot > 0 ? text.mid(dot) : QString{};
        QString lastLine;
        if (!suffix.isEmpty() && metrics.horizontalAdvance(suffix) < width) {
            const auto stem = remainder.left(qMax(0, remainder.size() - suffix.size()));
            lastLine = metrics.elidedText(stem, Qt::ElideRight, width - metrics.horizontalAdvance(suffix)) + suffix;
        } else {
            lastLine = metrics.elidedText(remainder, suffix.isEmpty() ? Qt::ElideRight : Qt::ElideMiddle, width);
        }
        const auto prefix = text.left(lastStart).trimmed();
        return prefix.isEmpty() ? lastLine : prefix + '\n' + lastLine;
    }

}
