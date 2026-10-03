#!/usr/bin/env bash

# Install host development tools only. Pedro build output stays under build/.
set -euo pipefail

if [[ "$(uname -s)" != Linux ]]; then
    echo "Pedro setup requires Ubuntu Linux." >&2
    exit 1
fi

if [[ ! -r /etc/os-release ]]; then
    echo "Cannot identify this Linux distribution (/etc/os-release is missing)." >&2
    exit 1
fi

# shellcheck source=/dev/null
. /etc/os-release

if [[ "${ID:-}" != ubuntu ]]; then
    echo "Pedro setup supports Ubuntu; detected ${PRETTY_NAME:-${ID:-unknown}}." >&2
    exit 1
fi

if ! command -v apt-get >/dev/null || ! command -v apt-cache >/dev/null || ! command -v dpkg >/dev/null; then
    echo "Pedro setup requires Ubuntu's apt-get and dpkg." >&2
    exit 1
fi

case "$(dpkg --print-architecture)" in
    amd64)
        imagePackages=(grub-efi-amd64-bin qemu-system-x86 ovmf)
        ;;
    arm64)
        imagePackages=(grub-efi-arm64-bin qemu-system-arm qemu-efi-aarch64)
        ;;
    *)
        echo "Pedro supports Ubuntu amd64 and arm64 hosts only." >&2
        exit 1
        ;;
esac

asRoot=()

if (( EUID != 0 )); then
    if ! command -v sudo >/dev/null; then
        echo "Install sudo or run this script as root." >&2
        exit 1
    fi

    sudo -v
    asRoot=(sudo)
fi

echo "Updating Ubuntu package indexes..."
"${asRoot[@]}" apt-get update

# Qt Quick Effects and other Qt modules are in Ubuntu's universe component.
effectsCandidate=$(apt-cache policy qml6-module-qtquick-effects | awk '$1 == "Candidate:" { print $2; exit }')

if [[ -z "$effectsCandidate" || "$effectsCandidate" == "(none)" ]]; then
    echo "Enabling Ubuntu universe for Pedro's Qt and TOML packages..."
    "${asRoot[@]}" apt-get install -y --no-install-recommends software-properties-common
    "${asRoot[@]}" add-apt-repository -y universe
    "${asRoot[@]}" apt-get update
fi

effectsCandidate=$(apt-cache policy qml6-module-qtquick-effects | awk '$1 == "Candidate:" { print $2; exit }')

if [[ -z "$effectsCandidate" || "$effectsCandidate" == "(none)" ]]; then
    echo "Qt Quick Effects is unavailable from this Ubuntu release's repositories." >&2
    exit 1
fi

qtVersion=$(apt-cache policy qt6-declarative-dev | awk '$1 == "Candidate:" { print $2; exit }')

if [[ -z "$qtVersion" || "$qtVersion" == "(none)" ]]; then
    echo "Qt 6 development packages are unavailable from the configured Ubuntu repositories." >&2
    exit 1
fi

if ! dpkg --compare-versions "$qtVersion" ge 6.8; then
    echo "Pedro requires Qt 6.8 or newer; Ubuntu offers $qtVersion." >&2
    echo "Use an Ubuntu release with Qt 6.8+ in its repositories." >&2
    exit 1
fi

packages=(
    build-essential cmake ninja-build python3 python3-gi pkg-config clang-format
    # Qt Linguist supplies lrelease, required to compile Pedro translation catalogs.
    qt6-l10n-tools
    qt6-base-dev qt6-declarative-dev qt6-svg-dev qt6-svg-plugins qt6-wayland-dev
    libglib2.0-dev libsystemd-dev libtomlplusplus-dev gvfs gvfs-backends
    # PAPI controls system audio through wpctl and watches changes with pw-mon.
    wireplumber pipewire-bin
    libwayland-dev wayland-protocols libxkbcommon-dev libegl-dev
    xkb-data
    qt6-qpa-plugins qt6-wayland qgnomeplatform-qt6
    qml6-module-qtqml qml6-module-qtqml-workerscript
    qml6-module-qtquick qml6-module-qtquick-window
    qml6-module-qtquick-layouts qml6-module-qtquick-controls
    qml6-module-qtquick-templates qml6-module-qtquick-effects
    qml6-module-qtwayland-compositor
    libgl1-mesa-dri fonts-dejavu-core
    rsync file binutils util-linux fdisk e2fsprogs dosfstools mtools grub-common
    qemu-system-gui
    "${imagePackages[@]}"
)

echo "Installing Pedro development and image-building dependencies..."
# Resolve the complete package set before changing installed packages.
"${asRoot[@]}" apt-get --simulate install --no-install-recommends "${packages[@]}"
"${asRoot[@]}" apt-get install -y --no-install-recommends "${packages[@]}"

# Ubuntu installs Qt 6 tools outside PATH; verify the tool CMake discovers.
lreleaseExecutable=/usr/lib/qt6/bin/lrelease

if [[ ! -x "$lreleaseExecutable" ]]; then
    echo "Qt 6 lrelease is missing after installing qt6-l10n-tools." >&2
    echo "Repair the package with: sudo apt-get install --reinstall qt6-l10n-tools" >&2
    exit 1
fi

"$lreleaseExecutable" -version

pkg-config --exists gio-2.0 gio-unix-2.0 libsystemd
sourceDirectory=$(dirname "$(realpath "$0")")
cmake -S "$sourceDirectory" \
    -B "$sourceDirectory/build/setup" -G Ninja \
    -DPEDRO_BUILD_IMAGE=OFF \
    -DPEDRO_BUILD_COMPOSITOR=ON \
    -DPEDRO_BUILD_INSTALLER=ON
echo "Pedro development dependencies are ready. Run 'make gui' for the GUI or 'make' for the image."
