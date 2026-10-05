#!/usr/bin/env bash
set -euo pipefail
sourceDirectory=$(cd "$(dirname "$0")/../../.." && pwd)
taskDirectory="$sourceDirectory/build/verification/search/service"
mkdir -p "$taskDirectory"
cat > "$taskDirectory/check.cpp" <<'CPP'
#include <gio/gio.h>
#include <pedro/papi/io/search/provider.h>
#include <QCoreApplication>
#include <iostream>

int main(int argc, char** argv) {
    QCoreApplication application(argc, argv);
    auto* cancellation = g_cancellable_new();
    const auto result = Pedro::Papi::Io::Search::query("file", cancellation);
    if (result.error.isEmpty() || !result.locations.isEmpty()) {
        return 1;
    }
    g_cancellable_cancel(cancellation);
    const auto canceled = Pedro::Papi::Io::Search::query("file", cancellation);
    g_object_unref(cancellation);
    if (!canceled.locations.isEmpty()) {
        return 1;
    }
    std::cout << "PASS: unavailable GNOME search reports an error; cancellation yields no results\n";
}
CPP
read -r -a flags <<< "$(pkg-config --cflags --libs Qt6Core gio-2.0)"
c++ -std=c++17 -fPIC -I "$sourceDirectory/build/dev/papi/include" \
    "$taskDirectory/check.cpp" "$sourceDirectory/papi/io/search/provider.cpp" \
    "${flags[@]}" -o "$taskDirectory/check"
# Deliberately unreachable session bus; never contact the user's index here.
DBUS_SESSION_BUS_ADDRESS="unix:path=$taskDirectory/nonexistent.sock" "$taskDirectory/check"
