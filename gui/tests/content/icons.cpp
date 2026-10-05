#include "application/icon/provider.hpp"

#include <QGuiApplication>

#include <iostream>

int main(int argc, char** argv) {
    QGuiApplication application(argc, argv);
    Pedro::Gui::Backend::Application::Icon::Provider provider;
    QSize actual;
    const auto image = provider.requestImage(QStringLiteral("pedro-test-icon"), &actual, QSize(18, 18));

    if (image.isNull() || actual != QSize(18, 18) || image.pixelColor(9, 9) != QColor(Qt::red)) {
        std::cerr << "Application SVG icon failed\n";
        return 1;
    }

    std::cout << "Application SVG icon passed\n";
    return 0;
}
