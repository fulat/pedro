#pragma once

#include <QFont>
#include <QString>

namespace Pedro::Gui::Backend::Entry {

    QString elideName(const QString& text, const QFont& font, qreal width, int lines, bool file);

}
