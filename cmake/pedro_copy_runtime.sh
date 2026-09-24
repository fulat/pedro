#!/usr/bin/env bash
#
# Pedro runtime dependency copier.
#
# Walks `ldd` of each Pedro binary and copies any not-yet-present
# library from the host system into the staged rootfs. Idempotent:
# re-running this script is safe.
#
# Usage:
#   pedro_copy_runtime.sh <rootfs-dir> <binary> [<binary> ...]
#
set -euo pipefail

rootfs="$1"
shift

declare -A seen

copy_one() {
    local src="$1"
    [[ -z "$src" || "$src" != /* ]] && return 0
    [[ -n "${seen[$src]:-}" ]] && return 0
    seen[$src]=1

    local real
    real="$(readlink -f "$src" 2>/dev/null || true)"
    [[ -z "$real" || "$real" != /* ]] && return 0
    [[ -f "$real" ]] || return 0

    local rel="${real#/}"
    local dst="$rootfs/$rel"
    [[ -e "$dst" ]] && return 0

    mkdir -p "$(dirname "$dst")"
    cp -P "$real" "$dst"
    echo "  copied $real -> $dst"
}

for bin in "$@"; do
    [[ -f "$bin" ]] || continue
    while read -r dep; do
        [[ -n "$dep" ]] && copy_one "$dep"
    done < <(ldd "$bin" 2>/dev/null | awk '/=> \// {print $3}' | sed 's/(0x[0-9a-f]*)//')
done

# Always copy the dynamic loader for our arch (ldd sometimes omits it
# for pie binaries).
for loader in \
    /lib/ld-linux-aarch64.so.1 \
    /lib/aarch64-linux-gnu/ld-linux-aarch64.so.1 \
    /usr/lib/aarch64-linux-gnu/ld-linux-aarch64.so.1 \
    /lib/ld-linux-x86-64.so.2 \
    /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 \
    /usr/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2; do
    [[ -f "$loader" ]] || continue
    real="$(readlink -f "$loader" 2>/dev/null || true)"
    [[ -z "$real" || ! -f "$real" ]] && continue
    dst="$rootfs${real#/}"
    [[ -e "$dst" ]] && continue
    mkdir -p "$(dirname "$dst")"
    cp -P "$real" "$dst"
    echo "  copied $real -> $dst"
done
