# AGENTS.md

Architectural and source-code rules for any agent, human or automated, modifying this repository.

These rules are non-negotiable for the Pedro OS project.

Agents must preserve the architecture, naming system, filesystem hierarchy, code style, and build boundaries described in this document.

---

## 1. Immutable Core

`core/` is the immutable Ubuntu base filesystem Pedro is built on top.

It is a source input, not a build artifact.

**Agents must NEVER:**

* modify any file inside `core/`
* delete files from `core/`
* create generated files inside `core/`
* install Pedro binaries into `core/`
* modify systemd configuration inside `core/`
* create symlinks inside `core/`
* patch configuration files directly inside `core/`
* run a build whose output directory is inside `core/`

The only legal relationship is:

```text
core/  ──READ / COPY──►  build/staging/rootfs/
```

Everything Pedro-specific is applied to the copied filesystem in:

```text
build/staging/rootfs/
```

or to a Pedro-owned overlay that is materialized inside it.

If something needs to change from Ubuntu's defaults, the change lives inside:

```text
build/staging/rootfs/
```

Never modify `core/`.

For GUI, PAPI, compositor, services, installer, and normal development tasks, agents must not inspect, search, index, grep, or traverse `core/`.

`core/` is reserved for the OS image and staging pipeline and may only be accessed when explicitly required by that pipeline.

---

## 2. Generated Output

All generated files belong under:

```text
build/
```

Never generate artifacts inside source directories.

In particular:

* no `.o`, `.a`, `.so`, or binaries inside `gui/`, `compositor/`, `papi/`, `installer/`, or other source directories
* no generated `CMakeCache.txt`
* no generated `build.ninja`
* no generated `cmake_install.cmake`
* no generated build trees inside source directories
* no helper-generated artifacts mixed with source files

The build directory is disposable.

The following must remain valid:

```bash
rm -rf build

cmake -S . -B build -G Ninja

cmake --build build
```

Deleting `build/` must never delete source data.

---

## 3. Services

`services/` contains systemd unit descriptors only.

It is **not** a directory for daemon source code.

**Agents must NEVER:**

* create `services/main.cpp`
* create `services/system/main.cpp`
* create executable source files inside `services/`
* add runtime libraries to `services/`
* compile anything from `services/`

Systemd units only describe how existing Pedro executables are launched.

Implementations belong inside their corresponding Pedro components.

Examples include:

```text
compositor/
gui/
installer/
papi/
```

---

## 4. Component Boundaries

Agents must preserve Pedro's existing architectural boundaries.

### `gui/`

Pedro's graphical shell and UI.

Implemented using Qt 6 Quick / QML.

Ships as:

```text
build/staging/rootfs/usr/bin/pedro-gui
```

Linked against:

```text
Qt6::Quick
```

Primary source:

```text
gui/main.cpp
gui/Main.qml
```

The GUI consumes PAPI for operating-system capabilities.

The GUI must not implement low-level Linux system behavior that belongs inside PAPI.

---

### `compositor/`

Pedro's display server.

Implemented using Qt 6 GUI and Qt Wayland Compositor.

Ships as:

```text
build/staging/rootfs/usr/bin/pedro-compositor
```

Linked against:

```text
Qt6::Quick
Qt6::WaylandCompositor
```

It also uses libsystemd readiness notification.

The compositor:

* provides the Wayland socket
* implements xdg-shell
* manages surfaces
* manages window position
* manages window size
* manages focus
* manages z-order
* manages visibility
* manages surface lifecycle

The compositor does **not** manage application content.

Primary source:

```text
compositor/main.cpp
compositor/Main.qml
```

---

### `papi/`

PAPI means:

```text
Pedro API
```

PAPI is Pedro's official system API layer between Pedro consumers and the underlying Linux system.

The previous `platform/` concept was renamed to:

```text
papi/
```

Never recreate `platform/`.

PAPI:

* exposes operating-system capabilities
* abstracts Linux implementation details
* may be consumed by the GUI
* may be consumed by Pedro components
* may be consumed by future Pedro applications
* must remain independent from GUI code
* must never depend on `gui/`
* must not become an executable

Linux implementations behind PAPI should use mature facilities when appropriate, including:

```text
standard C++
POSIX
Linux APIs
D-Bus
systemd
NetworkManager
PipeWire
UPower
Wayland
Qt
```

Do not recreate existing Linux subsystems unnecessarily.

---

### `installer/`

Pedro's installer application.

Implemented using Qt 6 Quick / QML.

Ships as:

```text
build/staging/rootfs/usr/bin/pedro-installer
```

It is built but is not currently part of the normal boot chain.

---

### `services/`

Contains only systemd `.service` files.

Installed under:

```text
build/staging/rootfs/usr/lib/systemd/system/
```

Enabled offline through:

```text
/etc/systemd/system/graphical.target.wants/
```

---

### `core/`

Immutable Ubuntu base filesystem.

Strictly read/copy only.

---

Agents must not invent new top-level architectural components without explicit justification.

Prefer extending Pedro's existing architecture over creating parallel systems.

The recognized architectural seams currently include:

```text
papi/
services/
compositor/
gui/
installer/
core/
```

Adding another top-level architectural component is a design decision, not a local implementation detail.

---

## 5. Root Filesystem

`build/staging/rootfs/` is generated.

It represents the filesystem that becomes `/` when Pedro runs.

It may be regenerated freely.

Never:

* treat it as source
* commit it
* manually preserve files inside it
* rely on manually modified contents

The same rule applies to:

```text
build/images/pedro.img
```

---

## 6. Reproducibility

Deleting `build/` must never destroy project source data.

Pedro must remain reconstructable from source plus the immutable `core/`.

The following pipeline must remain valid:

```bash
rm -rf build

cmake -S . -B build -G Ninja

cmake --build build

cmake --build build --target pedro-image
```

This must produce:

```text
build/images/pedro.img
```

for the host architecture when all image-building requirements are satisfied.

---

## 7. Linux Runtime

Pedro OS runtime artifacts are Linux artifacts.

The following must share the same Linux architecture:

```text
rootfs
kernel
initramfs
Pedro binaries
Pedro image
```

Supported architecture examples include:

```text
aarch64
x86_64
```

**Agents must NEVER:**

* introduce macOS Mach-O binaries into the Pedro rootfs
* introduce Windows PE binaries into the Pedro rootfs
* copy host binaries into the image unconditionally
* bypass architecture consistency checks
* bypass root CMake architecture verification

Host image tools such as:

```text
mtools
e2fsprogs
GRUB tooling
```

must never land inside the staged rootfs merely because they are used during image construction.

Downloaded or generated assembly inputs belong under:

```text
build/
```

---

## 8. Architecture Changes

Agents must inspect the existing Pedro architecture before introducing:

* new layers
* new directories
* new services
* new abstractions
* new top-level components
* new architectural patterns

Prefer extending the existing architecture.

Do not create a second mechanism when Pedro already has an architectural location for the responsibility.

---

## 9. Build Pipeline Overview

```text
source/  ──┐
            ├─► build/
core/   ────┘
                ├─► build/<CMake artifacts>
                │
                ├─► build/staging/rootfs/  (pedro-stage target)
                │       │
                │       ├─ copied from core/
                │       ├─ binaries installed by cmake --install
                │       ├─ runtime packages + kernel/initramfs
                │       └─ systemd units enabled offline
                │
                └─► build/images/pedro.img  (pedro-image target)
                        ├─ GPT
                        ├─ p1: FAT32 ESP
                        └─ p2: ext4 rootfs
```

Custom targets exposed by the root `CMakeLists.txt`:

| Target         | Responsibility                                                    |
| -------------- | ----------------------------------------------------------------- |
| `pedro-stage`  | Build and install into `build/staging/rootfs/`, then enable units |
| `pedro-verify` | Validate the staged rootfs                                        |
| `pedro-image`  | Run stage + verification + image creation                         |
| `pedro-all`    | Alias for `pedro-image`                                           |

---

## 10. Boot Chain

```text
UEFI firmware
    ↓
GPT
    ↓
p1 FAT32 ESP
    ↓
GRUB EFI binary
    ↓
GRUB reads /boot/grub/grub.cfg from ext4 rootfs
    ↓
kernel + initramfs
    ↓
systemd
    ↓
graphical.target
    ↓
compositor.service
    ↓
gui.service
```

Architecture-specific GRUB binaries include:

```text
grubaa64.efi
grubx64.efi
```

Kernel and initramfs names include:

```text
vmlinuz-pedro
initrd.img-pedro
```

All systemd dependencies such as:

```text
Requires=
BindsTo=
After=
```

belong inside unit files under:

```text
services/
```

Enablement is performed offline during staging.

---

## 11. Native Pipeline and Verification

The root CMake project invokes a generated copy of:

```text
pedro_pipeline.py
```

Older unreferenced CMake helper prototypes are not the active pipeline.

Configuration must not download packages.

Image builds require:

* native Linux
* the same Ubuntu release as `core/`
* root privileges
* private mount namespaces

The normal image build produces the Pedro image.

Development builds using:

```text
PEDRO_BUILD_IMAGE=OFF
```

build development applications only.

They must never stage incompatible host artifacts.

Staging fingerprints `core/` before and after operation.

The inaccessible snapd mountpoint:

```text
var/lib/snapd/void
```

is excluded and recreated only in staging.

An unprivileged-extracted base is normalized to root ownership during staging.

Native root-owned bases preserve numeric ownership.

Never modify ownership inside `core/`.

The compositor implements xdg-shell through Qt Wayland Compositor.

Its service uses:

```text
Type=notify
```

and starts the GUI only after the compositor renders its first frame.

The installer is built but is not enabled at boot.

The image uses:

* standalone GRUB EFI binary
* FAT32 ESP
* ext4 root filesystem populated through `mkfs.ext4 -d`

Do not introduce FUSE mounts for image generation.

Use filesystem labels.

Never hard-code:

```text
/dev/sda2
```

as Pedro's root device.

Deleting `build/` guarantees clean reconstruction, not byte-identical builds.

Ubuntu repositories are live.

Exact package versions are recorded in:

```text
build/staging/packages.txt
```

Never claim successful Pedro boot without VM or equivalent runtime evidence.

---

## 12. Normal Development

Normal GUI, PAPI, installer, and compositor development runs directly on Ubuntu with the image pipeline disabled.

Use incremental CMake/Ninja development builds.

Do not rebuild, stage, or generate full Pedro images for ordinary GUI or PAPI iteration.

Generated development output still belongs under:

```text
build/
```

Qt/QML owns Pedro's visual and application layer.

Prefer Qt facilities for:

* controls
* models
* media
* layouts
* signals
* slots
* application behavior

Do not unnecessarily recreate functionality already provided cleanly by Qt.

The GUI calls PAPI whenever it needs operating-system capabilities.

The compositor manages windows and surfaces.

It does not manage application content.

---

# Pedro Source Standard

The following rules define Pedro's canonical source-code structure.

These rules apply especially to PAPI and should be followed throughout Pedro-owned C and C++ code unless a component has an explicitly documented exception.

The purpose of these rules is predictability.

A developer or agent should be able to infer where code lives simply by reading its fully-qualified namespace.

---

## 13. Filesystem Naming

All Pedro-owned source directories and filenames must use lowercase names.

Examples:

```text
papi/
network/
device/
info.h
state.cpp
event.h
```

Never create source paths such as:

```text
Papi/
Network/
Device/
Info.h
NetworkDevice.h
networkDevice.h
network_device.h
network-device.h
```

Filesystem naming and C++ symbol naming are intentionally different systems.

Filesystem paths are always lowercase.

---

## 14. One Word per Path Segment

Pedro source filenames and directory names should represent one semantic word per path segment.

Compound filenames are forbidden when the same concept can be represented naturally through hierarchy.

Incorrect:

```text
networkdevice.h
network_device.h
network-device.h
networkDevice.h
deviceinfo.h
connectionstate.h
```

Correct:

```text
network/device.h
network/device/info.h
network/connection/state.h
```

Do not abbreviate compound concepts merely to force them into a single filename.

Incorrect:

```text
netdev.h
connstate.h
devinfo.h
```

Prefer semantic hierarchy:

```text
network/device.h
connection/state.h
device/info.h
```

The filesystem carries context.

The final filename represents the final entity.

---

## 15. Do Not Repeat Context

Directory context must not be redundantly repeated inside filenames or symbols.

For example:

```text
papi/network/device/info.h
```

should not contain a primary type named:

```cpp
NetworkDeviceInfo
```

Prefer:

```cpp
Info
```

inside:

```cpp
Pedro::Papi::Network::Device
```

The fully-qualified symbol is therefore:

```cpp
Pedro::Papi::Network::Device::Info
```

The hierarchy already communicates:

```text
Pedro
Papi
Network
Device
Info
```

Do not repeat information already provided by the path or namespace.

---

## 16. Hierarchy Must Be Semantic

Do not create directories merely to increase depth.

A directory should represent a real semantic context.

For example, both of the following may legitimately exist:

```text
papi/network/info.h
papi/network/device/info.h
```

These represent different concepts.

The corresponding symbols may be:

```cpp
Pedro::Papi::Network::Info
Pedro::Papi::Network::Device::Info
```

Use:

```text
network/info.h
```

when the information belongs directly to Network.

Use:

```text
network/device/info.h
```

when the information belongs specifically to a Network Device.

Do not introduce `device/` merely because networking happens to involve devices.

The hierarchy must describe ownership and context.

---

## 17. Namespace Hierarchy

C++ namespaces must reflect the semantic filesystem hierarchy.

Filesystem segments are lowercase.

Namespace segments use PascalCase.

Example source path:

```text
papi/network/device/info.h
```

corresponds to:

```cpp
namespace Pedro::Papi::Network::Device {
```

Mapping:

```text
pedro   → Pedro
papi    → Papi
network → Network
device  → Device
```

Namespaces must not combine semantic levels into compound names.

Incorrect:

```cpp
namespace Pedro::Papi::NetworkDevice {
```

Correct:

```cpp
namespace Pedro::Papi::Network::Device {
```

Another incorrect example:

```cpp
namespace PedroNetwork {
```

Correct:

```cpp
namespace Pedro::Network {
```

Each meaningful hierarchy level receives its own namespace segment.

---

## 18. Namespace and Filesystem Predictability

Pedro's namespace structure must remain predictable from the filesystem.

A developer seeing:

```cpp
Pedro::Papi::Network::Device::Info
```

should be able to infer that its source belongs conceptually at:

```text
papi/network/device/info.h
```

or its corresponding implementation file.

Do not place symbols into unrelated namespaces.

Do not create arbitrary namespace hierarchies that do not correspond to Pedro's source organization.

The filesystem and namespace hierarchy should behave as two representations of the same architecture.

---

## 19. Public Include Paths

Pedro public includes must preserve the lowercase filesystem convention.

When exposed through Pedro's public include root, prefer paths such as:

```cpp
#include <pedro/papi/network/info.h>
#include <pedro/papi/network/device/info.h>
#include <pedro/papi/network/device/state.h>
```

Do not capitalize public include paths merely because namespaces use PascalCase.

Incorrect:

```cpp
#include <Pedro/Papi/Network/Device/Info.h>
```

Correct:

```cpp
#include <pedro/papi/network/device/info.h>
```

Avoid relative traversal includes such as:

```cpp
#include "../../../network/device/info.h"
```

when the Pedro public include path is available.

---

## 20. Classes and Types

Classes and C++ types use PascalCase.

Examples:

```cpp
class Info
class State
class Event
class Device
class Manager
```

Pedro strongly prefers single-word class and type names when hierarchy already supplies the necessary context.

Avoid:

```cpp
class NetworkDeviceInfo
class DeviceConnectionState
class NetworkEventManager
```

when they can naturally become:

```cpp
Pedro::Papi::Network::Device::Info
Pedro::Papi::Network::Device::Connection::State
Pedro::Papi::Network::Event::Manager
```

Do not create meaningless directory depth purely to avoid every possible compound type.

The goal is semantic clarity, not mechanical fragmentation.

However, context should not be repeated unnecessarily inside type names.

---

## 21. Methods and Functions

Methods and functions use lower camelCase.

The first word begins lowercase.

Each following semantic word begins uppercase.

Correct:

```cpp
isConnected()
refreshInfo()
setEnabled()
requestConnection()
signalStrength()
currentDevice()
```

Incorrect:

```cpp
IsConnected()
refresh_info()
refresh-info()
RefreshInfo()
refreshinfo()
```

Functions inside namespaces follow the same rule.

Example:

```cpp
namespace Pedro::Papi::Network {

    bool isConnected();

    void refreshState();

}
```

---

## 22. Variables

Variables use lower camelCase.

Examples:

```cpp
connected
device
deviceState
signalStrength
connectionState
currentDevice
```

Do not use PascalCase for normal variables.

Avoid snake_case for Pedro-owned C++ variables unless required by an external API.

Incorrect:

```cpp
DeviceState
device_state
SIGNAL_STRENGTH
```

Correct:

```cpp
deviceState
signalStrength
```

---

## 23. Constants

Constants should follow the established semantic style of their surrounding API.

Prefer readable named constants and avoid unnecessary global macros.

Do not introduce C-style preprocessor constants when a typed C++ constant is appropriate.

Example:

```cpp
constexpr int defaultTimeout = 30;
```

Do not create arbitrary naming exceptions without architectural reason.

---

## 24. Brace Style

Pedro uses attached opening braces.

The opening brace belongs on the same line as the construct introducing the block.

Correct:

```cpp
namespace Pedro::Papi::Network {

}
```

Correct:

```cpp
class Info {

};
```

Correct:

```cpp
void refreshInfo() {

}
```

Correct:

```cpp
if (connected) {

}
```

Correct:

```cpp
for (const auto& device : devices) {

}
```

Incorrect:

```cpp
if (connected)
{

}
```

Incorrect:

```cpp
class Info
{

};
```

This rule applies to:

* namespaces
* classes
* structs
* enums when applicable
* functions
* methods
* constructors
* destructors
* `if`
* `else`
* `for`
* `while`
* `switch`
* `try`
* `catch`
* other C++ blocks

---

## 25. Indentation

Pedro uses four spaces for each indentation level.

Do not use hard tab characters for source indentation.

Each nested scope adds one visual indentation level.

Example:

```cpp
namespace Pedro::Papi::Network::Device {

    class Info {

        public:
            bool isConnected() const;

            void refreshInfo();

        private:
            bool connected;

            int signalStrength;

    };

}
```

The hierarchy must remain visually obvious.

Conceptually:

```text
namespace
    class
        access section
            method
            field
```

Namespace contents must be indented.

Class contents must be indented.

Access sections must be indented within classes.

Members must be indented beneath their access section.

Function bodies must be indented.

Control-flow blocks must be indented.

Nested scopes must continue the same pattern.

---

## 26. Access Modifiers

Access modifiers participate in the visual hierarchy.

Preferred:

```cpp
class Info {

    public:
        Info();

        bool isConnected() const;

    private:
        bool connected;

};
```

Do not flatten access modifiers against the class declaration level.

Avoid:

```cpp
class Info {

public:
    bool isConnected();

private:
    bool connected;

};
```

Pedro deliberately uses hierarchical indentation so code ownership is immediately visible.

---

## 27. Logical Spacing

Pedro source code should breathe visually.

Use blank lines to separate logically independent declarations and operations.

For example:

```cpp
bool isConnected() const;

int signalStrength() const;

void refreshInfo();
```

Prefer separating distinct methods rather than compressing declarations into dense blocks.

Inside implementations:

```cpp
void refreshInfo() {

    const auto device = currentDevice();

    if (!device) {
        return;
    }

    updateState(device);

    emitChanged();
}
```

A blank line should communicate a change in logical step.

Do not add blank lines randomly.

Do not use multiple consecutive blank lines without a strong reason.

Prefer one blank line between logical units.

The goal is visual clarity.

---

## 28. Function Structure

Functions should remain readable and visually divided into logical phases.

Prefer:

```cpp
void connectDevice() {

    const auto device = findDevice();

    if (!device) {
        return;
    }

    prepareDevice(device);

    connect(device);

    updateState();
}
```

Avoid unnecessarily compressed forms such as:

```cpp
void connectDevice() {
    const auto device = findDevice();
    if (!device) {
        return;
    }
    prepareDevice(device);
    connect(device);
    updateState();
}
```

Blank lines should separate conceptual operations when doing so improves readability.

Do not artificially split every individual statement.

Use semantic judgment.

---

## 29. Short Blocks

Do not collapse Pedro blocks into single-line forms merely because they are short.

Avoid:

```cpp
if (connected) { return; }
```

Prefer:

```cpp
if (connected) {
    return;
}
```

Avoid:

```cpp
bool enabled() const { return active; }
```

Prefer:

```cpp
bool enabled() const {
    return active;
}
```

Pedro prioritizes predictable visual structure over saving vertical space.

---

## 30. Includes

Keep include dependencies explicit and minimal.

A small file must not become an excuse to import an entire subsystem.

Prefer including only what the file actually needs.

For example:

```cpp
#include <pedro/papi/network/device/info.h>
```

should not indirectly require unrelated parts of:

```text
audio/
power/
storage/
gui/
```

unless there is a genuine architectural dependency.

Avoid umbrella headers that pull large portions of Pedro into every translation unit.

Header dependency discipline is more important to compilation performance than namespace depth or directory depth.

---

## 31. Include Grouping

Keep logically different include groups visually separated.

Example:

```cpp
#include <pedro/papi/network/device/info.h>

#include <QString>
#include <QVector>

#include <memory>
#include <string>
```

Suggested grouping:

```text
Pedro headers

Qt or framework headers

standard library / system headers
```

Do not reorder includes arbitrarily when doing so changes deliberate grouping.

---

## 32. Header Responsibility

Headers should expose only what consumers need.

Avoid unnecessarily large headers.

Prefer:

* forward declarations where appropriate
* narrow public interfaces
* implementation details in `.cpp`
* explicit dependencies
* small semantic units

Do not move large implementation bodies into headers without a concrete reason.

Do not create huge umbrella headers merely for convenience.

---

## 33. Source Responsibility

Each source file should have a clear semantic responsibility.

A file named:

```text
info.h
```

inside:

```text
papi/network/device/
```

should concern:

```text
Pedro::Papi::Network::Device::Info
```

or closely related functionality.

Do not turn generic files such as:

```text
utils.h
helpers.h
common.h
misc.h
```

into dumping grounds.

Prefer placing behavior in its real semantic domain.

---

## 34. Avoid Generic Utility Buckets

Do not create generic `utils/`, `helpers/`, or `misc/` areas simply because functionality does not immediately have an obvious home.

First determine which Pedro domain owns the behavior.

For example:

Network-related behavior belongs under:

```text
papi/network/
```

Power-related behavior belongs under:

```text
papi/power/
```

Audio-related behavior belongs under:

```text
papi/audio/
```

Only introduce genuinely shared abstractions when they are truly cross-domain.

---

## 35. Compile-Time Structure

Pedro may use deep semantic namespace and directory hierarchies when those hierarchies improve architecture.

Do not flatten meaningful structure merely out of concern for runtime performance.

Namespace depth does not represent runtime object traversal.

For example:

```cpp
Pedro::Papi::Network::Device::Info
```

is a compile-time symbol hierarchy.

It does not mean Pedro performs a runtime lookup through:

```text
Pedro
→ Papi
→ Network
→ Device
→ Info
```

Compilation performance should instead be protected through:

* narrow headers
* minimal includes
* clean dependency graphs
* implementation separation
* incremental builds

Do not sacrifice source predictability for negligible namespace-depth concerns.

---

## 36. PAPI Independence

PAPI must remain independently consumable.

PAPI must not depend on:

```text
gui/
```

The GUI may depend on PAPI.

PAPI may interact with Linux facilities and libraries required to expose system capabilities.

Keep implementation-specific Linux details behind PAPI interfaces whenever appropriate.

---

## 37. Code Style Is Part of Pedro Architecture

Pedro's formatting conventions are intentional.

Agents must write Pedro-style code directly.

Do not generate arbitrarily formatted C++ and assume a formatter will repair everything later.

The formatter is a verification and normalization mechanism.

It is not the source of Pedro's coding conventions.

Agents must understand and follow:

* naming
* filesystem hierarchy
* namespace hierarchy
* indentation
* brace placement
* logical spacing
* include discipline

while writing code.

---

## 38. clang-format

The repository's:

```text
.clang-format
```

defines Pedro's mechanical C/C++ formatting rules.

When `clang-format` is available, use the repository configuration.

The formatter may enforce mechanical properties such as:

* four-space indentation
* namespace indentation
* class indentation
* access-modifier indentation
* attached braces
* line wrapping
* spacing
* short-block expansion

It does **not** replace architectural rules in this document.

In particular, `clang-format` cannot decide whether:

```text
networkdevice.h
```

should instead be:

```text
network/device.h
```

Agents must make those decisions correctly before formatting.

---

## 39. Scoped Formatting

Do not run repository-wide formatting without an explicit reason.

In particular, never recursively format `core/`.

For PAPI work, formatting may be scoped to:

```text
papi/
```

Example:

```bash
find papi \
    -type f \
    \( -name "*.h" -o -name "*.cpp" \) \
    -exec clang-format --style=file -i {} +
```

This formats Pedro-owned C++ files within PAPI without traversing the immutable Ubuntu core.

Formatting may be scoped further when appropriate.

Example:

```bash
find papi/network \
    -type f \
    \( -name "*.h" -o -name "*.cpp" \) \
    -exec clang-format --style=file -i {} +
```

Do not use formatting commands that traverse unrelated repository areas unnecessarily.

---

## 40. Formatter Availability

Do not assume an IDE is responsible for formatting.

`clang-format` may be executed directly from the terminal.

CLion, VS Code, Codex, agents, scripts, and CI may all use the same repository `.clang-format`.

The repository format must therefore remain independent from a particular editor.

---

## 41. Canonical Pedro Example

A Pedro header should resemble the following structure:

```cpp
#pragma once

namespace Pedro::Papi::Network::Device {

    class Info {

        public:
            Info();

            bool isConnected() const;

            int signalStrength() const;

            void refreshInfo();

        private:
            bool connected;

            int strength;

    };

}
```

Corresponding source location:

```text
papi/network/device/info.h
```

When exposed through Pedro's public include hierarchy:

```cpp
#include <pedro/papi/network/device/info.h>
```

Fully-qualified type:

```cpp
Pedro::Papi::Network::Device::Info
```

This relationship is intentional:

```text
filesystem
    ↓
papi/network/device/info.h

namespace
    ↓
Pedro::Papi::Network::Device

type
    ↓
Info
```

The path provides context.

The namespace mirrors context.

The final symbol provides identity.

---

## 42. Canonical Method Example

Methods and variables use lower camelCase:

```cpp
namespace Pedro::Papi::Network {

    class State {

        public:
            bool isConnected() const;

            int signalStrength() const;

            void refreshState();

        private:
            bool connected;

            int currentStrength;

    };

}
```

Correct:

```text
isConnected
signalStrength
refreshState
currentStrength
```

Incorrect:

```text
IsConnected
signal_strength
RefreshState
current_strength
```

---

## 43. Canonical Hierarchy Example

A valid PAPI structure may look like:

```text
papi/
├── network/
│   ├── info.h
│   ├── state.h
│   ├── event.h
│   │
│   ├── device/
│   │   ├── info.h
│   │   └── state.h
│   │
│   └── connection/
│       ├── info.h
│       └── state.h
│
├── audio/
│   ├── info.h
│   │
│   ├── device/
│   │   ├── info.h
│   │   └── state.h
│   │
│   ├── input/
│   └── output/
│
└── power/
    ├── info.h
    ├── state.h
    │
    └── battery/
        ├── info.h
        └── state.h
```

Possible symbols include:

```cpp
Pedro::Papi::Network::Info

Pedro::Papi::Network::State

Pedro::Papi::Network::Device::Info

Pedro::Papi::Network::Device::State

Pedro::Papi::Network::Connection::Info

Pedro::Papi::Audio::Info

Pedro::Papi::Audio::Device::Info

Pedro::Papi::Power::State

Pedro::Papi::Power::Battery::Info
```

Repeated simple names such as `Info` and `State` are acceptable because their namespace supplies their meaning.

---

## 44. Architecture Before Convenience

Do not choose naming or file placement merely because it is faster to type.

Prefer:

```text
predictability
semantic hierarchy
discoverability
clear ownership
minimal repetition
```

over:

```text
short-term convenience
generic utility directories
compound filenames
duplicated context
arbitrary placement
```

A developer should usually be able to predict a file's location from its namespace and a namespace from its file location.

---

## 45. Agent Behavior

Before creating a Pedro source file, an agent must determine:

1. Which architectural component owns the functionality?
2. Which semantic namespace owns it?
3. Whether an existing directory already represents that context.
4. Whether another directory level is genuinely necessary.
5. What single-word filename represents the final entity.
6. What namespace follows from that hierarchy.
7. Whether the class or type can use a simple non-redundant name.
8. Which dependencies are genuinely required.

Agents must not invent compound filenames simply because they are common in other C++ projects.

Pedro's source architecture intentionally uses hierarchy instead.

---

## 46. Final Principle

Pedro source code should be predictable before it is opened.

Given:

```cpp
Pedro::Papi::Network::Device::Info
```

a developer should naturally expect something resembling:

```text
papi/network/device/info.h
```

Given:

```text
papi/power/battery/state.h
```

a developer should naturally expect something resembling:

```cpp
Pedro::Papi::Power::Battery::State
```

Pedro uses:

```text
filesystem hierarchy
namespace hierarchy
simple symbol names
consistent indentation
logical spacing
```

as parts of one coherent source architecture.

Do not break that relationship without an explicit architectural reason.

---

## 47. QML Component Hierarchy

QML must be divided by visual responsibility and behavior.

`Main.qml` is the shell composition root. It may compose the wallpaper, top-level chrome, and major panels, but it must not become a container for every control and view.

Reusable controls and independent views belong in separate QML files.

The one-word-per-path-segment rule also applies to QML. Use directory hierarchy to carry context.

Incorrect:

```text
qml/StatusButton.qml
qml/ControlCenter.qml
qml/QuickTile.qml
```

Correct:

```text
qml/status/Button.qml
qml/control/Center.qml
qml/quick/Tile.qml
```

Use qualified QML imports when simple type names repeat:

```qml
import "status" as Status
import "action" as Action

Status.Button {}
Action.Tile {}
```

Qt requires an instantiable QML type filename to begin with an uppercase letter. A single-word PascalCase QML type filename is therefore the explicit exception to the lowercase filename rule. Its directory context remains lowercase.

Do not create a generic QML `components/` bucket when a semantic directory such as `status/`, `media/`, `menu/`, or `control/` describes ownership more clearly.

---

## 48. End-of-Batch Formatting

At the end of every implementation batch, run the repository formatter and validation tools over the files in scope.

For Pedro-owned C and C++ files changed or directly involved in the batch, run:

```bash
clang-format --style=file -i <scoped files>
```

Formatting must remain scoped. Never recursively format the repository, `core/`, or generated files under `build/`.

Clang-format does not format QML. QML changes must additionally be checked with `qmllint`, and may use `qmlformat` when a repository QML formatting policy is available.

Always run the relevant incremental build after formatting so generated QML cache and C++ compilation remain verified.
