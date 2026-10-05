#include <pedro/papi/io/content/applications.hpp>

#include <QCoreApplication>
#include <QElapsedTimer>
#include <QFile>
#include <QFileInfo>
#include <QDir>
#include <QSignalSpy>
#include <QThread>

#include <cstdlib>
#include <functional>
#include <iostream>

namespace {

    void require(bool condition, const char* message) {
        if (!condition) {
            std::cerr << message << '\n';
            std::exit(1);
        }
    }

    void waitFor(const std::function<bool()>& ready) {
        QElapsedTimer timer;
        timer.start();
        while (!ready() && timer.elapsed() < 5000) {
            QCoreApplication::processEvents();
            QThread::msleep(5);
        }
        require(ready(), "Timed out waiting for application discovery/launch");
    }

}

int main(int argc, char** argv) {
    QCoreApplication application(argc, argv);
    using Pedro::Papi::Io::Content::Applications;
    Applications model;
    const auto fixture = QString::fromLocal8Bit(argv[1]);
    const auto output = QString::fromLocal8Bit(argv[2]);
    const auto source = QUrl::fromLocalFile(fixture);
    model.setSource(source);
    waitFor([&] { return !model.loading(); });
    require(model.error().isEmpty(), "File MIME discovery failed");
    const auto choices = model.applications();
    require(!choices.isEmpty(), "MIME-associated application missing");
    require(choices.first().toMap().value("id") == "pedro-fixture.desktop" && choices.first().toMap().value("isDefault").toBool(), "Default application must appear first");
    for (const auto& value : choices) {
        require(value.toMap().value("id") != "pedro-hidden.desktop", "Hidden applications must not appear");
    }
    require(!model.launch("not-associated.desktop"), "Arbitrary desktop IDs must be rejected");
    QSignalSpy launched(&model, &Applications::launched);
    require(model.launch("pedro-fixture.desktop"), "Cannot launch associated application");
    require(!model.launch("pedro-fixture.desktop"), "Repeated launch while busy must be rejected");
    waitFor([&] { return !launched.isEmpty() && QFile::exists(output); });
    QFile record(output);
    require(record.open(QIODevice::ReadOnly), "Cannot inspect application argument");
    const auto argument = QString::fromUtf8(record.readAll());
    const auto opened = argument.startsWith("file:") ? QUrl(argument) : QUrl::fromLocalFile(argument);
    require(opened == source, "Launch must pass the exact file without shell interpretation");
    QSignalSpy failed(&model, &Applications::failed);
    require(QFile::remove(QFileInfo(fixture).dir().filePath("missing-handler")), "Cannot remove test application executable");
    model.launch("pedro-broken.desktop");
    waitFor([&] { return !failed.isEmpty(); });
    require(!model.error().isEmpty(), "Launch failure must be visible to consumers");
    model.setSource(QUrl::fromLocalFile(fixture + ".missing"));
    waitFor([&] { return !model.loading(); });
    require(!model.error().isEmpty() && model.applications().isEmpty(), "Missing file must report an error without stale applications");
    model.setSource(source);
    model.setSource({});
    waitFor([&] { return !model.loading(); });
    QThread::msleep(50);
    QCoreApplication::processEvents();
    require(model.applications().isEmpty() && model.error().isEmpty(), "Superseded queries must not restore old results");
    std::cout << "PASS: MIME applications, default ordering, exact URI launch, hidden entries and stale queries\n";
}
