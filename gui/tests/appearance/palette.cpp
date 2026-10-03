#include "../../backend/appearance/palette.hpp"

#include <QColor>
#include <QCoreApplication>
#include <QDir>
#include <QImage>
#include <QDebug>

#include <algorithm>

int main(int argc, char** argv) {
    QCoreApplication app(argc, argv);
    const QString output = QString::fromLocal8Bit(argv[1]);
    QDir().mkpath(output);
    const auto firstPath = output + "/red-blue.png";
    const auto secondPath = output + "/green.png";
    QImage image(32, 32, QImage::Format_ARGB32);
    image.fill(Qt::red);
    for (int y = 16; y < 32; ++y) {
        for (int x = 0; x < 32; ++x) {
            image.setPixelColor(x, y, Qt::blue);
        }
    }
    if (!image.save(firstPath))
        return 1;
    image.fill(Qt::green);
    if (!image.save(secondPath))
        return 1;

    Pedro::Gui::Appearance::Palette palette;
    const auto first = palette.snapshot(QUrl::fromLocalFile(firstPath));
    const auto top = first.value("darkTop").value<QColor>();
    const auto bottom = first.value("darkBottom").value<QColor>();
    if (top.red() <= top.blue() || bottom.blue() <= bottom.red())
        return 2;
    for (const auto& value : first) {
        const auto color = value.value<QColor>();
        const auto minimum = std::min({color.red(), color.green(), color.blue()});
        const auto maximum = std::max({color.red(), color.green(), color.blue()});
        if (color.alpha() != 255 || maximum - minimum > 12)
            return 3;
    }
    if (top.lightnessF() > 0.3 || bottom.lightnessF() > 0.3)
        return 4;
    if (palette.snapshot(QUrl::fromLocalFile(firstPath)) != first)
        return 5;
    const auto second = palette.snapshot(QUrl::fromLocalFile(secondPath));
    if (second == first || first.value("darkTop").value<QColor>() != top)
        return 6;
    if (!palette.snapshot(QUrl::fromLocalFile(output + "/missing.png")).isEmpty())
        return 7;
    qInfo() << "Wallpaper palette: opaque, dark, restrained hue, snapshot stability and fallback PASSED";
    return 0;
}
