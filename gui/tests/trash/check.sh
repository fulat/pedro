#!/usr/bin/env bash
set -euo pipefail
sourceDirectory=$(cd "$(dirname "$0")/../../.." && pwd)
taskDirectory="$sourceDirectory/build/verification/trash"
testUserHome=$(python3 -c 'import os, pwd; print(pwd.getpwuid(os.getuid()).pw_dir)')
testUserId=$(id -u)
mkdir -p "$taskDirectory"
testHome=$(mktemp -d "$taskDirectory/home.XXXXXX")
/usr/lib/qt6/libexec/moc "$sourceDirectory/papi/io/trash/manager.h" -o "$taskDirectory/moc.cpp"
/usr/lib/qt6/libexec/moc "$sourceDirectory/papi/io/directory/model.hpp" -o "$taskDirectory/directory.cpp"
/usr/lib/qt6/libexec/moc "$sourceDirectory/papi/io/transfer/manager.hpp" -o "$taskDirectory/transfer.cpp"
read -r -a flags <<< "$(pkg-config --cflags --libs Qt6Gui Qt6Concurrent gio-2.0 gio-unix-2.0)"
c++ -std=c++17 -fPIC -I "$sourceDirectory/build/dev/papi/include" \
    "$sourceDirectory/gui/tests/trash/check.cpp" "$sourceDirectory/papi/io/trash/manager.cpp" \
    "$taskDirectory/moc.cpp" "$taskDirectory/directory.cpp" "$taskDirectory/transfer.cpp" \
    "$sourceDirectory/papi/io/transfer/manager.cpp" \
    "$sourceDirectory/papi/io/directory/model.cpp" "$sourceDirectory/papi/io/content/icon.cpp" "${flags[@]}" -o "$taskDirectory/check"
# Never expose the host home, mounts, session bus or actual Trash to this process.
bwrap --unshare-all --die-with-parent --ro-bind /usr /usr --ro-bind /etc /etc \
    --symlink usr/lib /lib --symlink usr/lib64 /lib64 --symlink usr/bin /bin --dev /dev --proc /proc \
    --tmpfs /tmp --tmpfs /run --dir "/run/user/$testUserId" \
    --bind "$testHome" "$testUserHome" --ro-bind "$taskDirectory/check" /check \
    --setenv XDG_RUNTIME_DIR "/run/user/$testUserId" --setenv XDG_DATA_HOME "$testUserHome/.local/share" \
    --setenv PEDRO_TRASH_TEST_SANDBOX 1 dbus-run-session -- /check
