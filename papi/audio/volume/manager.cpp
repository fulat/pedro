#include "manager.h"

#include <QRegularExpression>
#include <QStandardPaths>

#include <algorithm>

namespace Pedro::Papi::Audio::Volume {

    Manager::Manager(QObject* parent) : QObject(parent) {
        updates.setSingleShot(true);
        updates.setInterval(80);
        debounce.setSingleShot(true);
        debounce.setInterval(75);
        connect(&updates, &QTimer::timeout, this, &Manager::refresh);
        connect(&debounce, &QTimer::timeout, this, &Manager::write);
        connect(&monitor, &QProcess::readyReadStandardOutput, this, [this] {
            monitor.readAllStandardOutput();
            updates.start();
        });
        connect(&monitor, &QProcess::readyReadStandardError, this, [this] { monitor.readAllStandardError(); });
        connect(&reader, qOverload<int, QProcess::ExitStatus>(&QProcess::finished), this, [this](int code, QProcess::ExitStatus status) {
            const auto output = QString::fromUtf8(reader.readAllStandardOutput());
            const auto match = QRegularExpression(QStringLiteral("Volume:\\s*([0-9]+(?:\\.[0-9]+)?)")).match(output);
            supported = code == 0 && status == QProcess::NormalExit && match.hasMatch();
            if (supported) {
                percentage = std::clamp(qRound(match.captured(1).toDouble() * 100), 0, 100);
                silent = output.contains("[MUTED]");
                failure.clear();
            } else {
                failure = QString::fromUtf8(reader.readAllStandardError()).trimmed();
            }
            emit changed();
            if (refreshPending) {
                refreshPending = false;
                updates.start();
            }
        });
        connect(&reader, &QProcess::errorOccurred, this, [this] {
            supported = false;
            failure = reader.errorString();
            emit changed();
        });
        connect(&writer, qOverload<int, QProcess::ExitStatus>(&QProcess::finished), this, [this](int code, QProcess::ExitStatus status) {
            if (code != 0 || status != QProcess::NormalExit) {
                failure = QString::fromUtf8(writer.readAllStandardError()).trimmed();
                emit changed();
            }
            if (code == 0 && status == QProcess::NormalExit && writer.arguments().value(0) == "set-volume" && silent) {
                writer.setArguments({"set-mute", "@DEFAULT_AUDIO_SINK@", "0"});
                writer.start();
                return;
            }
            updates.start();
            if (requested >= 0 || requestedMute >= 0) {
                debounce.start();
            }
        });
        connect(&writer, &QProcess::errorOccurred, this, [this] {
            failure = writer.errorString();
            emit changed();
        });
        const auto tool = QStandardPaths::findExecutable("wpctl");
        const auto events = QStandardPaths::findExecutable("pw-mon");
        if (tool.isEmpty() || events.isEmpty()) {
            failure = QStringLiteral("Audio control is unavailable");
            return;
        }
        reader.setProgram(tool);
        writer.setProgram(tool);
        monitor.start(events, QStringList{});
        QTimer::singleShot(0, this, &Manager::refresh);
    }

    Manager::~Manager() {
        monitor.kill();
        monitor.waitForFinished(100);
    }

    bool Manager::available() const {
        return supported;
    }

    int Manager::value() const {
        return percentage;
    }

    bool Manager::muted() const {
        return silent;
    }

    QString Manager::error() const {
        return failure;
    }

    void Manager::refresh() {
        if (reader.program().isEmpty()) {
            return;
        }
        if (reader.state() != QProcess::NotRunning) {
            refreshPending = true;
            return;
        }
        reader.setArguments({"get-volume", "@DEFAULT_AUDIO_SINK@"});
        reader.start();
    }

    void Manager::setValue(int value) {
        if (!supported) {
            return;
        }
        requested = std::clamp(value, 0, 100);
        debounce.start();
    }

    void Manager::toggleMuted() {
        if (!supported) {
            return;
        }
        requestedMute = requestedMute >= 0 ? !requestedMute : !silent;
        debounce.start();
    }

    void Manager::write() {
        if (!supported || (requested < 0 && requestedMute < 0) || writer.state() != QProcess::NotRunning) {
            return;
        }
        if (requestedMute >= 0) {
            writer.setArguments({"set-mute", "@DEFAULT_AUDIO_SINK@", QString::number(requestedMute)});
            requestedMute = -1;
            writer.start();
            return;
        }
        const auto value = requested;
        requested = -1;
        writer.setArguments({"set-volume", "@DEFAULT_AUDIO_SINK@", QString::number(value) + "%"});
        writer.start();
    }
}
