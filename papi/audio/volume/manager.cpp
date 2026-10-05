#include "manager.h"

#include <QRegularExpression>
#include <QStandardPaths>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>

#include <algorithm>

namespace Pedro::Papi::Audio::Volume {

    Manager::Manager(QObject* parent) : QObject(parent) {
        updates.setSingleShot(true);
        updates.setInterval(80);
        debounce.setSingleShot(true);
        debounce.setInterval(75);
        connect(&updates, &QTimer::timeout, this, &Manager::refresh);
        connect(&debounce, &QTimer::timeout, this, &Manager::write);
        connect(&monitor, &QProcess::readyReadStandardOutput, this, &Manager::readEvents);
        connect(&monitor, &QProcess::readyReadStandardError, this, [this] { monitor.readAllStandardError(); });
        connect(&reader, qOverload<int, QProcess::ExitStatus>(&QProcess::finished), this, [this](int code, QProcess::ExitStatus status) {
            const auto output = QString::fromUtf8(reader.readAllStandardOutput());
            const auto match = QRegularExpression(QStringLiteral("Volume:\\s*([0-9]+(?:\\.[0-9]+)?)")).match(output);
            const auto previousSupported = supported;
            const auto previousPercentage = percentage;
            const auto previousSilent = silent;
            const auto previousFailure = failure;
            supported = code == 0 && status == QProcess::NormalExit && match.hasMatch();
            if (supported) {
                percentage = std::clamp(qRound(match.captured(1).toDouble() * 100), 0, 100);
                silent = output.contains("[MUTED]");
                failure.clear();
            } else {
                failure = QString::fromUtf8(reader.readAllStandardError()).trimmed();
            }
            if (previousSupported != supported || previousPercentage != percentage || previousSilent != silent || previousFailure != failure) {
                emit changed();
            }
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
        const auto events = QStandardPaths::findExecutable("pw-dump");
        if (tool.isEmpty() || events.isEmpty()) {
            failure = QStringLiteral("Audio control is unavailable");
            return;
        }
        reader.setProgram(tool);
        writer.setProgram(tool);
        monitor.start(events, {QStringLiteral("--monitor"), QStringLiteral("--no-colors")});
        QTimer::singleShot(0, this, &Manager::refresh);
    }

    Manager::~Manager() {
        for (auto* process : {&monitor, &reader, &writer}) {
            if (process->state() != QProcess::NotRunning) {
                process->kill();
                process->waitForFinished(1000);
            }
        }
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

    void Manager::readEvents() {

        eventBuffer += monitor.readAllStandardOutput();
        // pw-dump streams complete JSON arrays. Preserve partial records, including
        // brackets inside quoted properties, until the next process output chunk.
        int depth = 0;
        bool quoted = false;
        bool escaped = false;
        int consumed = 0;
        bool relevant = false;
        for (int index = 0; index < eventBuffer.size(); ++index) {
            const auto character = eventBuffer.at(index);
            if (quoted) {
                if (escaped) {
                    escaped = false;
                } else if (character == '\\') {
                    escaped = true;
                } else if (character == '"') {
                    quoted = false;
                }
                continue;
            }
            if (character == '"') {
                quoted = true;
            } else if (character == '[') {
                ++depth;
            } else if (character == ']' && --depth == 0) {
                const auto document = QJsonDocument::fromJson(eventBuffer.mid(consumed, index + 1 - consumed));
                for (const auto& value : document.array()) {
                    const auto object = value.toObject();
                    const auto id = object.value(QStringLiteral("id")).toInt(-1);
                    const auto type = object.value(QStringLiteral("type")).toString();
                    if (type == QStringLiteral("PipeWire:Interface:Node") || type == QStringLiteral("PipeWire:Interface:Metadata")) {
                        watchedObjects.insert(id);
                        relevant = true;
                    } else if (watchedObjects.contains(id)) {
                        relevant = true;
                        if (object.value(QStringLiteral("info")).isNull()) {
                            watchedObjects.remove(id);
                        }
                    }
                }
                consumed = index + 1;
            }
        }
        eventBuffer.remove(0, consumed);
        if (relevant) {
            updates.start();
        }
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
