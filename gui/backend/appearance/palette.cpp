#include "palette.hpp"

#include <QColor>
#include <QFileInfo>
#include <QImage>
#include <QImageReader>

#include <algorithm>

namespace Pedro::Gui::Appearance {
    namespace {

        QColor average(const QImage& image, int start, int end) {
            double red = 0;
            double green = 0;
            double blue = 0;
            double weight = 0;

            for (int y = start; y < end; ++y) {
                for (int x = 0; x < image.width(); ++x) {
                    const auto pixel = image.pixelColor(x, y);
                    const auto alpha = pixel.alphaF();
                    red += pixel.redF() * alpha;
                    green += pixel.greenF() * alpha;
                    blue += pixel.blueF() * alpha;
                    weight += alpha;
                }
            }

            if (weight == 0) {
                return QColor::fromRgbF(0.5, 0.5, 0.5);
            }

            return QColor::fromRgbF(red / weight, green / weight, blue / weight);
        }

        QColor tint(const QColor& sample, double base) {
            const auto luminance = sample.redF() * 0.2126 + sample.greenF() * 0.7152 + sample.blueF() * 0.0722;
            const auto gray = base + (luminance - 0.5) * 0.025;
            const auto channel = [gray, luminance](double value) {
                // A restrained hue around gray avoids colorful or near-black patches.
                return std::clamp(gray + std::clamp(value - luminance, -0.16, 0.16) * 0.14, 0.0, 1.0);
            };

            return QColor::fromRgbF(channel(sample.redF()), channel(sample.greenF()), channel(sample.blueF()), 1.0);
        }
    }

    QVariantMap Palette::snapshot(const QUrl& wallpaper) const {
        const auto path = wallpaper.isLocalFile() ? wallpaper.toLocalFile() : wallpaper.scheme() == "qrc" ? ":" + wallpaper.path() : QString{};
        if (path.isEmpty()) {
            return {};
        }

        const QFileInfo file(path);
        if (path == source && file.lastModified() == modified && file.size() == fileSize) {
            return colors;
        }

        QImageReader reader(path);
        reader.setAutoTransform(true);
        reader.setScaledSize(QSize(32, 32));
        const auto image = reader.read();
        source = path;
        modified = file.lastModified();
        fileSize = file.size();
        colors.clear();
        if (image.isNull()) {
            return colors;
        }

        const auto middle = std::max(1, image.height() / 2);
        const auto top = average(image, 0, middle);
        const auto bottom = average(image, middle < image.height() ? middle : 0, image.height());
        colors.insert("darkTop", tint(top, 0.22));
        colors.insert("darkBottom", tint(bottom, 0.19));
        colors.insert("lightTop", tint(top, 0.91));
        colors.insert("lightBottom", tint(bottom, 0.87));
        return colors;
    }
}
