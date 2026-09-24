# Pedro

Pedro combines an immutable Ubuntu root filesystem with a Qt Wayland compositor,
Qt Quick shell, and installer. The default CMake build assembles a bootable UEFI
raw disk image. The installer is built but is not part of startup.

## Ubuntu-native application development

The normal GUI development loop runs directly on Ubuntu and does not touch the
OS image pipeline:

```sh
sudo apt-get install build-essential cmake ninja-build qt6-base-dev qt6-declarative-dev qt6-svg-dev
make start
```

`make start` configures `build/dev` with `PEDRO_BUILD_IMAGE=OFF`, incrementally
builds PAPI and `pedro-gui`, and launches the GUI in a desktop window. It does
not need root, read or copy `core/`, stage a root filesystem, or build an image.
It uses Ubuntu's standard Qt 6 CMake packages, so no Qt path variable is needed.
`make dev`, `make GUI`, and `make gui` are equivalent aliases. `make gui-build`
performs the build without launching.

During development the executable loads `gui/Main.qml` directly from the source
tree. After the first build, `make qml` relaunches the existing executable
without invoking CMake or Ninja, which provides the shortest QML-only iteration
loop. C++ and PAPI changes use `make dev` and Ninja recompiles only what changed.

Use `make diagnose` when investigating display quality. It launches the same
Ubuntu-native GUI and reports the active Qt platform, session type, screen and
window device-pixel ratios, logical and physical DPI, physical backing size,
scene-graph backend, OpenGL renderer, and any Qt scaling overrides. The command
does not force a scale factor or graphics backend, so its output describes the
real desktop session rather than a synthetic configuration.

The current end-to-end slice is:

```text
QML dashboard/editor
        ↓
GUI QObject adapter
        ↓
Pedro::Papi::{System, Filesystem}
        ↓
/proc, POSIX, and standard C++ filesystem APIs on the Ubuntu host
```

The dashboard shows live hostname, kernel, architecture, uptime, CPU, and memory
state. Its editor loads and saves a developer-selected real file through PAPI.
No mock values are used. NetworkManager, power, battery, audio, and display
modules are intentionally deferred until a corresponding UI capability needs
them.

## Native Linux build

Use Ubuntu **matching `core/etc/os-release`**, on the same architecture as core
(`aarch64` or `x86_64`). This checkout contains an Ubuntu 26.04 ARM64 base.
Qt 6.5 or newer is required. Do not configure the image build with a macOS Qt SDK.

Install host build tools (ARM64):

```sh
sudo apt-get update
sudo apt-get install --no-install-recommends \
  build-essential cmake ninja-build python3 pkg-config \
  qt6-base-dev qt6-declarative-dev qt6-svg-dev qt6-wayland-dev libsystemd-dev \
  rsync file binutils util-linux e2fsprogs dosfstools mtools \
  grub-common grub-efi-arm64-bin qemu-system-arm qemu-efi-aarch64
```

On x86_64, replace the last line with
`grub-common grub-efi-amd64-bin qemu-system-x86 ovmf`.
The host and staged APT sources must provide compatible Qt packages. Custom Qt
SDKs are not supported by this package-based deployment path.

```sh
cmake -S . -B build -G Ninja
sudo cmake --build build --parallel 4
# Equivalent explicit image target:
sudo cmake --build build --target pedro-image --parallel 4
```

Once the host prerequisites are installed, the same full build is available as:

```sh
make
```

`make` is Linux-only. It detects a CMake cache created through a different
absolute mount path (for example `/media/psf/...`) and, after the sudo prompt,
removes the disposable `build/` directory before configuring it again. It does
not touch `core/` or source files. Run it from the native Ubuntu/Linux checkout,
not from macOS.

Staging needs root for Linux ownership, chroot, and a private mount namespace.
Package scripts run only in the staged root, with service startup suppressed.
The build does not install packages on the host. Network access is required for
staged Ubuntu packages, including the virtual-machine kernel and initramfs tools.
A container needs mount/chroot privileges and a **read-only source/core mount**
with a separate writable Linux filesystem mounted at `/src/build`.

Targets:

| Target | Result |
|---|---|
| `pedro_gui`, `pedro_compositor`, `pedro_installer` | Compile one application |
| `pedro-stage` | Recreate rootfs, install packages, kernel and units |
| `pedro-verify` | Stage, then validate architecture, libraries and boot setup |
| `pedro-image` | Verify, then assemble `build/images/pedro.img` |
| `pedro-all` (default) | Complete image pipeline |

The root CMake file runs a generated copy of `pedro_pipeline.py`. The older
unreferenced scripts in `cmake/` are prototypes, not active build entry points.
No build helper writes to `core/`. All generated output belongs under `build/`.

## Staged filesystem and boot

```text
build/
  cmake/pedro_pipeline.py          generated helper
  staging/
    core.sha256                   input fingerprint
    packages.txt                  exact installed package versions
    rootfs/
      usr/bin/pedro-compositor
      usr/bin/pedro-gui
      usr/bin/pedro-installer
      usr/lib/systemd/system/{compositor,gui}.service
      usr/lib/modules/<kernel-version>/
      etc/systemd/system/default.target -> /usr/lib/systemd/system/graphical.target
      etc/systemd/system/graphical.target.wants/{compositor,gui}.service
      etc/pedro/{environment,kernel-version}
      boot/{vmlinuz-pedro,initrd.img-pedro,grub/grub.cfg}
    image/{esp.raw,root.raw,BOOTAA64.EFI}   BOOTX64.EFI on x86_64
  images/pedro.img
```

Boot: UEFI → standalone GRUB in a 64 MiB FAT32 ESP → kernel/initramfs →
ext4 `LABEL=PEDROROOT` → systemd `graphical.target` → compositor readiness → GUI.
The compositor's first rendered frame sends `READY=1`; only then does systemd
start the GUI. Both use `/run/pedro/wayland-0`. The compositor owns DRM via EGLFS;
Wayland clients use shared-memory rendering for this milestone. Services run as
root, without a login manager. Hardware overrides belong in the **staged**
`/etc/pedro/environment`; never edit core.

The disk uses GPT, an EFI fallback loader, and an ext4 root partition sized from
the staged filesystem plus headroom. GRUB locates the root by label, independent
of the VM disk name. `mkfs.ext4 -d` populates the root partition without FUSE or
loop-device mounts. Failed builds do not publish `.partial` images.

## VM smoke test

ARM64, on Linux (TCG works without KVM):

```sh
qemu-system-aarch64 -machine virt -cpu cortex-a72 -accel tcg \
  -m 3072 -smp 2 -bios /usr/share/AAVMF/AAVMF_CODE.fd \
  -drive if=none,id=pedro,format=raw,file=build/images/pedro.img \
  -device virtio-blk-pci,drive=pedro -device virtio-gpu-pci \
  -device qemu-xhci -device usb-kbd -device usb-tablet \
  -nic none -serial mon:stdio -display gtk -snapshot
```

x86_64, on Linux:

```sh
qemu-system-x86_64 -machine q35 -accel tcg -m 3072 -smp 2 \
  -bios /usr/share/OVMF/OVMF_CODE_4M.fd \
  -drive if=none,id=pedro,format=raw,file=build/images/pedro.img \
  -device virtio-blk-pci,drive=pedro -device virtio-vga \
  -device qemu-xhci -device usb-kbd -device usb-tablet \
  -nic none -serial mon:stdio -display gtk -snapshot
```

Install `qemu-system-gui` if the GTK display backend is not present. For a
headless host, replace `-display gtk` with `-display vnc=127.0.0.1:1` and connect
locally to VNC port 5901. Secure Boot must be disabled. A successful test shows
“Pedro” on screen and the compositor/GUI services starting in the serial log.

## Application development

```sh
make gui-build                   # incrementally compiles PAPI + GUI into build/dev/
make gui                         # compiles and opens Pedro's GUI
make dev                         # same Ubuntu-native development loop
make qml                         # relaunches with source QML; no build step
make diagnose                    # launches GUI and logs the rendering pipeline
make compositor                  # Linux; run nested in an existing desktop
```

These targets configure with `PEDRO_BUILD_IMAGE=OFF`. They do not inspect or
copy `core/`, stage runtime packages, create systemd enablement, or create an
image. The runtime needs a working Ubuntu desktop session and Qt 6.5 or newer.
Pass custom CMake settings with `DEV_CMAKE_ARGS`, for example
`make dev DEV_CMAKE_ARGS='-DCMAKE_PREFIX_PATH=/opt/Qt/6.8/gcc_64'`.

GUI development works from a Parallels shared folder. Image staging does not:
the staged Ubuntu root filesystem and kernel modules need local Linux filesystem
semantics. If this checkout is under `/media/psf`, mount a local directory at
the repository's `build/` path before running `make`:

```sh
sudo rm -rf build
mkdir -p ~/pedro-build build
sudo mount --bind ~/pedro-build "$PWD/build"
make
# Later, after exporting any artifacts:
sudo umount "$PWD/build"
```

The bind mount keeps all generated paths logically under `build/`, while the
bytes live on the local Linux filesystem. The image pipeline detects Parallels,
9p, VirtualBox, and VMware shared filesystems and stops before staging instead
of failing during kernel-package extraction.

`make build`, `make stage`, `make verify`, and `make image` wrap the
corresponding CMake targets; use a root shell for staging/image commands.
`make clean` removes generated output only (root may be needed after staging).

## Milestone limits

Single output and basic xdg-shell surfaces; no window management, installer boot
workflow, recovery, updates, encryption or Secure Boot. The VM kernel package
keeps firmware payloads small; physical hardware may need additional modules or
firmware. Software rendering prioritizes a simple VM smoke test over performance.

Rebuilding from a clean `build/` reconstructs the image, but is not byte-for-byte
reproducible: APT repositories, timestamps and filesystem IDs can change.
`staging/packages.txt` records the resolved package versions.

Core fingerprints cover file contents, modes, owners and symlinks. The empty,
inaccessible snapd `var/lib/snapd/void` mountpoint is excluded and recreated in
staging. If the base was extracted as an unprivileged user (e.g. on macOS), the
staged copy is normalized to root ownership; native root-owned bases preserve
numeric ownership. `core/` is never changed.

## Validation completed in this checkout

Validated on native ARM64 Linux in an Ubuntu 26.04 Docker container, with the
source tree (including core) mounted read-only. All three executables compiled;
staged GUI and installer clients connected to the Pedro Wayland compositor.
A direct notification test received `READY=1` after the compositor's first frame.
The final image booted through UEFI/GRUB/kernel/systemd in QEMU TCG and displayed
“Pedro”. x86_64 and physical hardware have not been boot-tested.

The full pipeline was exercised with:

```sh
docker exec pedro-build-check cmake -S /src -B /src/build -G Ninja
docker exec pedro-build-check cmake --build /src/build --target pedro-image -j 4
```

The final compositor readiness adjustment was then compiled, installed into the
staged rootfs, verified, and imaged again with the same pipeline helper.

The test artifacts remain in container `pedro-build-check`:

- `/src/build/images/pedro.img` and `pedro.img.sha256` (~2.13 GiB raw image).
- `/src/build/staging/rootfs/` and the package/core manifests.
- `/src/build/validation/final-boot-screen.png` and `final-boot-serial.log`.
- Build, verification and readiness-test logs under `/src/build/validation/`.

The Mac workspace's existing `build/` is root-owned, so exporting to it was
blocked. From the repository directory, export the image and evidence with:

```sh
sudo chown -R "$(id -u):$(id -g)" build
docker cp pedro-build-check:/src/build/images build/
docker cp pedro-build-check:/src/build/validation build/
```

Keep the rootfs in Linux to preserve device nodes and Linux ownership semantics.
Do not remove the container with its volume before exporting desired artifacts.

Implementation changes: root CMake orchestration, `pedro_pipeline.py`, `makefile`,
`.gitignore`, `README.md`, `AGENTS.md`; compositor CMake/C++/QML; GUI CMake/QML;
installer CMake/C++ (module-name fix); compositor and GUI systemd units.
The pre-existing PAPI and service install rules were retained.
