#include <pedro/papi/io/file/information.h>

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QtTest>

#include <iostream>

int main(int argc, char** argv) {
    QCoreApplication app(argc, argv);
    if (argc != 2)
        return 1;
    const auto path = QString::fromLocal8Bit(argv[1]);
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly))
        return 2;
    file.write("Metadata fixture\n");
    file.close();
    Pedro::Papi::Io::File::Information information;
    information.setSource(QUrl::fromLocalFile(path));
    if (!QTest::qWaitFor([&] { return !information.loading(); }, 5000))
        return 6;
    const auto data = information.data();
    if (!information.error().isEmpty() || data.value("size").toLongLong() != 17 || data.value("location").toString() != QFileInfo(path).absolutePath() || data.value("owner").toString().isEmpty() || !data.value("readable").toBool() || !data.value("writable").toBool() || !data.value("modified").toDateTime().isValid())
        return 3;
    information.setSource(QUrl::fromLocalFile(path + ".missing"));
    if (!QTest::qWaitFor([&] { return !information.loading(); }, 5000))
        return 6;
    if (information.error().isEmpty() || !information.data().isEmpty())
        return 4;
    information.setSource(QUrl::fromLocalFile(path));
    information.setSource(QUrl());
    QTest::qWait(100);
    if (information.loading() || !information.data().isEmpty())
        return 5;
    std::cout << "PASS: real GIO metadata, missing file and superseded source\n";
    return 0;
}
