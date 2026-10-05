#include <pedro/papi/audio/volume/manager.h>

#include <QCoreApplication>
#include <QFile>
#include <QTimer>

#include <iostream>

int main(int argc, char** argv) {
    QCoreApplication app(argc, argv);
    Pedro::Papi::Audio::Volume::Manager manager;
    int changes = 0;
    QObject::connect(&manager, &Pedro::Papi::Audio::Volume::Manager::changed, &app, [&] { ++changes; });
    QTimer::singleShot(1800, &app, [&] {
        QFile queries(QString::fromLocal8Bit(argv[1]) + "/queries");
        if (!queries.open(QIODevice::ReadOnly)) {
            app.exit(1);
            return;
        }
        const auto count = queries.readAll().count('\n');
        if (!manager.available() || manager.value() != 42 || !manager.muted() || changes != 3 || count > 5 || count < 3) {
            std::cerr << "FAIL: volume=" << manager.value() << " mute=" << manager.muted() << " notifications=" << changes << " queries=" << count << '\n';
            app.exit(1);
            return;
        }
        std::cout << "PASS: partial JSON, client noise, external volume/mute and default output changes; " << count << " queries, " << changes << " state notifications\n";
        app.quit();
    });
    return app.exec();
}
