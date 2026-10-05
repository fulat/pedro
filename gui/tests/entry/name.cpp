#include "../../backend/entry/name.h"

#include <QGuiApplication>
#include <QFontMetricsF>

#include <cstdlib>
#include <iostream>

void require(bool condition, const char* message) {
    if (!condition) {
        std::cerr << message << '\n';
        std::exit(1);
    }
}

int main(int argc, char** argv) {
    QGuiApplication app(argc, argv);
    QFont font;
    font.setPixelSize(13);
    const auto shortName = QStringLiteral("photo.png");
    require(Pedro::Gui::Backend::Entry::elideName(shortName, font, 130, 2, true) == shortName, "Short names must remain unchanged");
    const auto longName = QStringLiteral("Vacation photographs from Santo Domingo and the Caribbean coastline, final edited version.png");
    const auto result = Pedro::Gui::Backend::Entry::elideName(longName, font, 110, 2, true);
    require(result.contains(QChar(0x2026)) && result.endsWith(".png"), "Elision must preserve the extension");
    const auto lines = result.split('\n');
    require(lines.size() == 2, "Long names must use two lines");
    const QFontMetricsF metrics(font);
    for (const auto& line : lines) {
        require(metrics.horizontalAdvance(line) <= 111, "Elided lines must fit the label width");
    }
    const auto folder = Pedro::Gui::Backend::Entry::elideName(longName, font, 110, 2, false);
    require(folder.endsWith(QChar(0x2026)) && !folder.endsWith(".png"), "Folder names must elide normally");
    require(Pedro::Gui::Backend::Entry::elideName(longName, font, 0, 2, true).isEmpty(), "Unmeasured labels must not produce overflow");
    std::cout << "PASS: two-line names and preserved extensions\n";
}
