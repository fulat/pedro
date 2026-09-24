#!/usr/bin/env bash
#
# Fetch host-side tools required by pedro-image that are not part of
# a typical base Ubuntu install (mtools and fuse2fs). These are not
# Pedro runtime artifacts - they only participate in image assembly
# and never end up inside the resulting Pedro filesystem.
#
# Usage:
#   pedro_fetch_tools.sh <tools-dir>
#
# Downloads the Debian packages into <tools-dir>, extracts them, and
# prints (one per line) the absolute paths of the binaries we need.
#
set -euo pipefail

tools="$1"
mkdir -p "$tools"

need_mformat=0
need_fuse2fs=0

# Detect existing tools in PATH first; only fetch if missing.
for tool in mformat mmd mcopy fuse2fs; do
    case "$tool" in
        mformat|mmd|mcopy)
            if ! command -v "$tool" >/dev/null 2>&1; then
                need_mformat=1
            fi
            ;;
        fuse2fs)
            if ! command -v "$tool" >/dev/null 2>&1; then
                need_fuse2fs=1
            fi
            ;;
    esac
done

cd "$tools"

if [[ "$need_mformat" == 1 ]]; then
    echo "  downloading mtools .deb"
    apt-get download mtools >/dev/null
    for deb in mtools_*.deb; do
        dpkg-deb -x "$deb" "${tools}/mtools/"
    done
    rm -f mtools_*.deb
fi

if [[ "$need_fuse2fs" == 1 ]]; then
    echo "  downloading fuse2fs .deb"
    apt-get download fuse2fs >/dev/null
    for deb in fuse2fs_*.deb; do
        dpkg-deb -x "$deb" "${tools}/fuse2fs/"
    done
    rm -f fuse2fs_*.deb
fi

# Locate the binaries we care about and print their absolute paths.
emit() {
    local bin="$1"
    local path
    if command -v "$bin" >/dev/null 2>&1; then
        command -v "$bin"
    elif [[ -x "${tools}/mtools/usr/bin/${bin}" ]]; then
        echo "${tools}/mtools/usr/bin/${bin}"
    elif [[ -x "${tools}/fuse2fs/usr/bin/${bin}" ]]; then
        echo "${tools}/fuse2fs/usr/bin/${bin}"
    else
        echo ""
    fi
}

emit mformat
emit mmd
emit mcopy
emit fuse2fs
