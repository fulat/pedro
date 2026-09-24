#!/usr/bin/env bash
#
# Fetch the host's kernel and build a matching minimal initramfs.
# Used as a fallback when /boot/vmlinuz is not readable by the build
# user (typical for production Ubuntu installs where /boot is 0600
# and owned by root).
#
# Usage:
#   pedro_fetch_kernel.sh <out-dir> <arch>
#
# Where <arch> is "aarch64" or "x86_64". The script places
# vmlinuz-pedro and initrd.img-pedro inside <out-dir>.
#
set -euo pipefail

out="$1"
arch="$2"
mkdir -p "$out"
cd "$out"

# Pick the right kernel flavour for the arch.
case "$arch" in
    aarch64)
        flavour="arm64"
        ;;
    x86_64)
        flavour="amd64"
        ;;
    *)
        echo "Unsupported architecture: $arch" >&2
        exit 1
        ;;
esac

# ----------------------------------------------------------------
# Step 1: fetch kernel from linux-image package
# ----------------------------------------------------------------
ver="$(uname -r)"
candidate_pkg="linux-image-${ver}"
echo "  trying concrete package: $candidate_pkg"
if ! apt-get download "$candidate_pkg" 2>/dev/null; then
    echo "  falling back to metapackage: linux-image-generic"
    apt-get download linux-image-generic
fi

shopt -s nullglob
for deb in *.deb; do
    work="$(mktemp -d)"
    dpkg-deb -x "$deb" "$work"

    while read -r vmlinuz; do
        echo "  found kernel: $vmlinuz"
        cp "$vmlinuz" "${out}/vmlinuz-pedro"
    done < <(find "$work" -name 'vmlinuz-*' -type f -size +1M)

    rm -rf "$work"
    rm -f "$deb"
done
shopt -u nullglob

if [[ ! -f "${out}/vmlinuz-pedro" ]]; then
    echo "ERROR: kernel image not found inside any downloaded linux-image package" >&2
    exit 1
fi

# ----------------------------------------------------------------
# Step 2: build a minimal initramfs
# ----------------------------------------------------------------
# We can't read /boot/initrd.img (root only). Instead, we build a
# minimal CPIO from a statically-linked busybox that knows how to
# mount the rootfs and hand off to systemd.
if [[ ! -x /usr/bin/busybox ]]; then
    echo "ERROR: /usr/bin/busybox not found; cannot build minimal initramfs" >&2
    exit 1
fi

initramfs_root="$(mktemp -d)"
trap 'rm -rf "$initramfs_root"' EXIT

mkdir -p "${initramfs_root}/bin"
mkdir -p "${initramfs_root}/sbin"
mkdir -p "${initramfs_root}/proc"
mkdir -p "${initramfs_root}/sys"
mkdir -p "${initramfs_root}/dev"
mkdir -p "${initramfs_root}/lib"
mkdir -p "${initramfs_root}/usr/bin"
mkdir -p "${initramfs_root}/usr/sbin"
mkdir -p "${initramfs_root}/usr/lib"
mkdir -p "${initramfs_root}/etc"
mkdir -p "${initramfs_root}/newroot"

# Install static busybox and symlink its applets.
cp /usr/bin/busybox "${initramfs_root}/bin/busybox"
chmod +x "${initramfs_root}/bin/busybox"
for applet in sh mount umount switch_root mkdir mknod sleep cat echo ls modprobe insmod; do
    ln -sf /bin/busybox "${initramfs_root}/bin/${applet}"
done

# /init: bootstrap the real rootfs and hand off to systemd.
cat > "${initramfs_root}/init" <<'INIT_EOF'
#!/bin/sh
set -e

# Mount the virtual filesystems the kernel didn't already set up.
mount -t proc     proc     /proc
mount -t sysfs    sys      /sys
mount -t devtmpfs devtmpfs /dev

# Wait for the root block device to appear (it lives behind a GPT
# partition on /dev/sda2 by default; Pedro's GRUB points us here).
echo "Pedro initramfs: waiting for root device /dev/sda2..."
i=0
while [ ! -b /dev/sda2 ] && [ $i -lt 30 ]; do
    sleep 1
    i=$((i + 1))
done
if [ ! -b /dev/sda2 ]; then
    echo "Pedro initramfs: /dev/sda2 did not appear; dropping to shell"
    exec /bin/sh
fi

# Mount the Pedro rootfs read-write.
mount -o rw /dev/sda2 /newroot

# Hand off to systemd inside the real rootfs.
exec switch_root /newroot /sbin/init
INIT_EOF
chmod +x "${initramfs_root}/init"

# Build the CPIO archive (newc format, gzip-compressed).
( cd "${initramfs_root}" && \
    find . -print0 | cpio --null --create --format=newc ) \
    | gzip -9 > "${out}/initrd.img-pedro"

echo "  kernel staged at ${out}/vmlinuz-pedro"
echo "  initramfs staged at ${out}/initrd.img-pedro ($(stat -c %s "${out}/initrd.img-pedro" 2>/dev/null || stat -f %z "${out}/initrd.img-pedro") bytes)"
