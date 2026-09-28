#!/usr/bin/env python3
"""Native Linux build helper; source/core are read-only, all output is in build/."""
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import stat
import struct
import subprocess
import sys


def run(*args, **kwargs):
    print('+', ' '.join(map(str, args)), flush=True)
    return subprocess.run(list(map(str, args)), check=True, **kwargs)


def out(*args):
    return subprocess.check_output(list(map(str, args)), text=True).strip()


def need(ok, message):
    if not ok:
        raise RuntimeError(message)


def resolve(root, name):
    """Resolve image symlinks against image /, never host /."""
    parts, result, links = list(Path(name.lstrip('/')).parts), [], 0
    while parts:
        part = parts.pop(0)
        if part in ('', '.'):
            continue
        if part == '..':
            need(result, f'Path escapes rootfs: {name}')
            result.pop()
            continue
        path = root.joinpath(*result, part)
        if path.is_symlink():
            links += 1
            need(links < 40, f'Symlink cycle: {name}')
            target = os.readlink(path)
            if target.startswith('/'):
                result = []
            parts = list(Path(target.lstrip('/')).parts) + parts
        else:
            result.append(part)
    return root.joinpath(*result)


def elf(path, arch):
    with path.open('rb') as stream:
        data = stream.read(20)
    need(data[:6] == b'\x7fELF\x02\x01', f'Not Linux ELF64: {path}')
    need(struct.unpack('<H', data[18:20])[0] == {'aarch64': 183, 'x86_64': 62}[arch],
         f'Wrong architecture: {path}; expected {arch}')


def manifest(root):
    digest = hashlib.sha256()
    def visit(path):
        # Empty snapd sandbox mountpoint can be unreadable on shared filesystems.
        if path.relative_to(root).as_posix() == 'var/lib/snapd/void':
            digest.update(b'snapd-void-mountpoint')
            return
        st = path.lstat()
        digest.update(json.dumps([str(path.relative_to(root)), st.st_mode, st.st_uid,
                                 st.st_gid, st.st_size, st.st_mtime_ns]).encode())
        if path.is_symlink():
            digest.update(os.readlink(path).encode())
        elif stat.S_ISREG(st.st_mode):
            with path.open('rb') as stream:
                for block in iter(lambda: stream.read(1024 * 1024), b''):
                    digest.update(block)
        elif stat.S_ISDIR(st.st_mode):
            # snapd's empty sandbox mountpoint is intentionally mode 000.
            if path.relative_to(root).as_posix() == 'var/lib/snapd/void' and stat.S_IMODE(st.st_mode) == 0:
                return
            for child in sorted(path.iterdir()):
                visit(child)
    visit(root)
    return digest.hexdigest()


def check(source, build, arch):
    need(platform.system() == 'Linux' and platform.machine() == arch, 'Native Linux architecture required.')
    need(build.is_relative_to(source / 'build'), 'Output must be inside build/.')
    need(not (source / 'build').is_symlink(), 'build/ may not be a symlink.')
    filesystem = out('stat', '-f', '-c', '%T', build)
    unsupported_filesystems = {'9p', 'fuse.prl_fs', 'prl_fs', 'vboxsf', 'vmhgfs'}
    need(filesystem not in unsupported_filesystems,
         f"Pedro image staging requires a local Linux filesystem, but build/ is on '{filesystem}'. "
         'Use make gui for GUI development, or bind-mount a local ext4/xfs/btrfs directory at build/.')
    core = source / 'core'
    need(core.is_dir() and not core.is_symlink(), 'core/ must be a rootfs directory.')
    elf(resolve(core, '/usr/bin/dpkg'), arch)
    need(resolve(core, '/usr/lib/systemd/systemd').is_file(), 'core/ needs systemd.')


def stage(source, build, arch):
    need(os.geteuid() == 0, 'Stage requires root on Linux for ownership, chroot and initramfs; see README.')
    core, root = source / 'core', build / 'staging/rootfs'
    need(not (build / 'staging').is_symlink() and not root.is_symlink(), 'Unsafe staging symlink.')
    mounts_now = [line.split()[4].replace('\\040', ' ') for line in Path('/proc/self/mountinfo').read_text().splitlines()]
    need(not any(p == str(root) or p.startswith(str(root) + '/') for p in mounts_now), 'Unmount stale staging mounts first.')
    before = manifest(core)
    mounts = []
    try:
        if root.exists():
            shutil.rmtree(root)
        root.mkdir(parents=True)
        copy_options = ['--exclude=/var/lib/snapd/void']
        if (core / 'etc/passwd').stat().st_uid != 0:
            print('Normalizing ownership of a user-extracted base to root:root.')
            copy_options.append('--chown=0:0')
        run('rsync', '-aHAX', '--numeric-ids', *copy_options, str(core) + '/', str(root) + '/')
        # The extraction directory's private mode is not the mode of Linux /.
        root.chmod(0o755)
        void = root / 'var/lib/snapd/void'
        void.mkdir(parents=True, exist_ok=True)
        void.chmod(0)
        for name in ('usr', 'usr/bin', 'etc', 'boot', 'var', 'run'):
            need(not (root / name).is_symlink(), f'Unsafe base layout: {name}')
        def release(path):
            return dict(re.findall(r'^(\w+)="?([^"\n]+)"?$', path.read_text(), re.M))
        host, base = release(Path('/etc/os-release')), release(root / 'etc/os-release')
        need(host.get('ID') == base.get('ID') == 'ubuntu' and host.get('VERSION_ID') == base.get('VERSION_ID'),
             'Build host and core must use the same Ubuntu release (Qt ABI).')
        for name in ('proc', 'sys', 'dev', 'run', 'etc/pedro', 'boot/grub'):
            (root / name).mkdir(parents=True, exist_ok=True)
        for name in ('dev', 'proc', 'sys'):
            run('mount', '--rbind', '/' + name, root / name)
            mounts.append(root / name)
            run('mount', '--make-rslave', root / name)
        cache = build / 'tools/apt-archives'
        cache.mkdir(parents=True, exist_ok=True)
        archives = root / 'var/cache/apt/archives'
        archives.mkdir(parents=True, exist_ok=True)
        run('mount', '--bind', cache, archives)
        mounts.append(archives)
        resolver = root / 'etc/resolv.conf'
        resolver.unlink(missing_ok=True)
        resolver.write_text(Path('/etc/resolv.conf').read_text())
        policy = root / 'usr/sbin/policy-rc.d'
        saved_policy = (policy.read_bytes(), stat.S_IMODE(policy.stat().st_mode)) if policy.exists() else None
        policy.write_text('#!/bin/sh\nexit 101\n')
        policy.chmod(0o755)
        (root / 'etc/fstab').write_text('LABEL=PEDROROOT / ext4 defaults 0 1\n')
        env = dict(os.environ, DEBIAN_FRONTEND='noninteractive')
        run('chroot', root, 'apt-get', 'update', env=env)
        packages = ['systemd-sysv', 'dbus', 'udev', 'initramfs-tools', 'linux-image-virtual',
                    'libqt6concurrent6', 'qt6-qpa-plugins', 'qt6-wayland', 'qgnomeplatform-qt6',
                    'qml6-module-qtquick',
                    'qml6-module-qtquick-window', 'qml6-module-qtquick-layouts',
                    'qml6-module-qtquick-controls', 'qml6-module-qtquick-templates',
                    'qml6-module-qtqml-workerscript', 'qml6-module-qtwayland-compositor',
                    'libgl1-mesa-dri', 'libegl-mesa0', 'fonts-dejavu-core']
        run('chroot', root, 'apt-get', 'install', '-y', '--no-install-recommends', *packages, env=env)
        run('cmake', '--install', build, '--prefix', root)
        shutil.copytree(source / 'gnome/appearance/gtk/Pedro', root / 'usr/share/themes/Pedro', dirs_exist_ok=True)
        shutil.copytree(source / 'gnome/appearance/icons/Pedro', root / 'usr/share/icons/Pedro', dirs_exist_ok=True)
        run('chroot', root, 'ldconfig')
        version = out('chroot', root, 'sh', '-c', 'ls /lib/modules | sort -V | tail -1')
        need(version and (root / f'boot/vmlinuz-{version}').is_file(), 'Missing kernel/module pair.')
        with (root / 'etc/initramfs-tools/modules').open('a') as stream:
            stream.write('\n# Pedro VM drivers\nvirtio_pci\nvirtio_blk\nvirtio_scsi\nvirtio_gpu\next4\n')
        run('chroot', root, 'depmod', version)
        initrd = root / f'boot/initrd.img-{version}'
        run('chroot', root, 'update-initramfs', '-u' if initrd.exists() else '-c', '-k', version)
        (root / 'boot/vmlinuz-pedro').symlink_to(f'vmlinuz-{version}')
        (root / 'boot/initrd.img-pedro').symlink_to(f'initrd.img-{version}')
        (root / 'etc/pedro/kernel-version').write_text(version + '\n')
        system = root / 'etc/systemd/system'
        wants = system / 'graphical.target.wants'
        wants.mkdir(parents=True, exist_ok=True)
        def link(path, target):
            path.unlink(missing_ok=True)
            path.symlink_to(target)
        for unit in ('compositor.service', 'gui.service'):
            link(wants / unit, '/usr/lib/systemd/system/' + unit)
        link(system / 'default.target', '/usr/lib/systemd/system/graphical.target')
        link(system / 'display-manager.service', '/dev/null')
        (root / 'etc/fstab').write_text('LABEL=PEDROROOT / ext4 defaults 0 1\n')
        (root / 'etc/hostname').write_text('pedro\n')
        machine_id = root / 'etc/machine-id'
        machine_id.unlink(missing_ok=True)
        machine_id.touch()
        dbus_id = root / 'var/lib/dbus/machine-id'
        dbus_id.parent.mkdir(parents=True, exist_ok=True)
        link(dbus_id, '/etc/machine-id')
        (root / 'etc/pedro/environment').write_text('# Target hardware Qt overrides.\n')
        (root / 'boot/grub/grub.cfg').write_text('''set timeout=1
set default=0
menuentry 'Pedro' {
    search --no-floppy --label PEDROROOT --set=root
    linux /boot/vmlinuz-pedro root=LABEL=PEDROROOT rootwait rw console=tty0 console=ttyAMA0 console=ttyS0
    initrd /boot/initrd.img-pedro
}
'''.replace(' console=ttyS0' if arch == 'aarch64' else ' console=ttyAMA0', ''))
        # Keep downloaded packages outside the rootfs for subsequent clean staging runs.
        if saved_policy:
            policy.write_bytes(saved_policy[0])
            policy.chmod(saved_policy[1])
        else:
            policy.unlink()
        resolver.unlink()
        base_resolver = core / 'etc/resolv.conf'
        if base_resolver.is_symlink():
            resolver.symlink_to(os.readlink(base_resolver))
        elif base_resolver.exists():
            shutil.copy2(base_resolver, resolver)
        (build / 'staging/packages.txt').write_text(out('chroot', root, 'dpkg-query', '-W') + '\n')
    finally:
        for mount in reversed(mounts):
            run('umount', '-R', mount)
        need(manifest(core) == before, 'Immutable core changed during staging!')
    # Minimal static nodes also make offline chroot verification self-contained.
    for name, major, minor, mode in [('null', 1, 3, 0o666), ('zero', 1, 5, 0o666),
                                      ('random', 1, 8, 0o666), ('urandom', 1, 9, 0o666),
                                      ('console', 5, 1, 0o600), ('tty', 5, 0, 0o666)]:
        node = root / 'dev' / name
        node.unlink(missing_ok=True)
        os.mknod(node, stat.S_IFCHR | mode, os.makedev(major, minor))
        node.chmod(mode)
    (build / 'staging/core.sha256').write_text(before + '\n')


def verify(source, build, arch):
    root = build / 'staging/rootfs'
    need(manifest(source / 'core') == (build / 'staging/core.sha256').read_text().strip(), 'core/ changed since staging.')
    for name in ('usr/bin/pedro-compositor', 'usr/bin/pedro-gui', 'usr/bin/pedro-installer', 'usr/lib/systemd/systemd'):
        elf(resolve(root, name), arch)
        result = out('chroot', root, 'ldd', '/' + name)
        need('not found' not in result, f'Missing libraries for {name}:\n{result}')
    for unit in ('compositor.service', 'gui.service'):
        path = root / 'usr/lib/systemd/system' / unit
        for executable in re.findall(r'^ExecStart=(/\S+)', path.read_text(), re.M):
            need(os.access(resolve(root, executable), os.X_OK), f'Missing ExecStart: {executable}')
        link = root / 'etc/systemd/system/graphical.target.wants' / unit
        need(link.is_symlink() and resolve(root, str(link.relative_to(root))) == path, f'Unit not enabled: {unit}')
    need(resolve(root, 'etc/systemd/system/default.target') == root / 'usr/lib/systemd/system/graphical.target', 'Wrong default.target.')
    for name in ('boot/vmlinuz-pedro', 'boot/initrd.img-pedro', 'boot/grub/grub.cfg'):
        need((root / name).is_file() and (root / name).stat().st_size, f'Missing boot file: {name}')
    with (root / 'boot/vmlinuz-pedro').open('rb') as stream:
        kernel = stream.read(1024)
    # Recent Ubuntu ARM kernels use the Linux EFI zboot PE wrapper.
    # This is a Linux boot artifact, not a Windows runtime executable.
    pe_offset = struct.unpack('<I', kernel[60:64])[0] if kernel[:2] == b'MZ' else 0
    pe_arm = (pe_offset + 6 <= len(kernel) and kernel[pe_offset:pe_offset+4] == b'PE\0\0'
              and struct.unpack('<H', kernel[pe_offset+4:pe_offset+6])[0] == 0xaa64)
    need((arch == 'aarch64' and (kernel[56:60] == b'ARM\x64' or pe_arm)) or
         (arch == 'x86_64' and kernel[514:518] == b'HdrS'), 'Kernel architecture mismatch.')
    version = (root / 'etc/pedro/kernel-version').read_text().strip()
    need((root / 'usr/lib/modules' / version / 'modules.dep').is_file(), 'Missing kernel modules.')
    plugins = 0
    for path in (root / 'usr').rglob('*'):
        if path.is_symlink() or not path.is_file():
            continue
        with path.open('rb') as stream:
            magic = stream.read(4)
        need(magic not in (b'\xcf\xfa\xed\xfe', b'\xfe\xed\xfa\xcf'), f'Mach-O in image: {path}')
        if magic == b'\x7fELF':
            elf(path, arch)
            if '/qt6/' in str(path) and '.so' in path.name:
                plugins += 1
                result = out('chroot', root, 'ldd', '/' + str(path.relative_to(root)))
                need('not found' not in result, f'Unresolved Qt plugin: {path}\n{result}')
    need(plugins, 'Qt plugins absent.')
    qml_roots = list((root / 'usr/lib').glob('*/qt6/qml'))
    for module in ('QtQuick', 'QtQuick/Window', 'QtQuick/Layouts', 'QtQuick/Controls/Basic',
                   'QtQuick/Templates', 'QtQml/WorkerScript',
                   'QtWayland/Compositor', 'QtWayland/Compositor/XdgShell'):
        need(any((q / module / 'qmldir').is_file() for q in qml_roots), f'Missing QML module: {module}')
    plugin_roots = list((root / 'usr/lib').glob('*/qt6/plugins'))
    need(any((p / 'platforms/libqeglfs.so').is_file() for p in plugin_roots), 'Missing EGLFS backend.')
    need(any(list((p / 'platforms').glob('libqwayland*.so')) for p in plugin_roots), 'Missing Wayland client backend.')
    need(any((p / 'platformthemes/libqgnomeplatformtheme.so').is_file() for p in plugin_roots),
         'Missing Qt GNOME platform theme.')
    need(any((p / 'wayland-decoration-client/libqgnomeplatformdecoration.so').is_file() for p in plugin_roots),
         'Missing Qt GNOME Wayland decoration.')
    for name in ('usr/share/themes/Pedro/gtk-3.0/gtk.css', 'usr/share/themes/Pedro/gtk-4.0/gtk.css',
                 'usr/share/icons/Pedro/index.theme',
                 'usr/share/icons/Pedro/scalable/ui/window-close-symbolic.svg'):
        need((root / name).is_file(), f'Missing Pedro appearance asset: {name}')
    initramfs = out('chroot', root, 'lsinitramfs', '/boot/initrd.img-pedro')
    need('init' in initramfs.splitlines() and version in initramfs, 'Initramfs missing init or matching modules.')
    run('chroot', root, 'systemd-analyze', 'verify', 'compositor.service', 'gui.service')
    print('Rootfs verified; immutable core unchanged.', flush=True)


def image(source, build, arch):
    root, images, work = build / 'staging/rootfs', build / 'images', build / 'staging/image'
    images.mkdir(parents=True, exist_ok=True)
    work.mkdir(parents=True, exist_ok=True)
    for tool in ('grub-mkstandalone', 'mkfs.ext4', 'mkfs.fat', 'mmd', 'mcopy', 'sfdisk', 'e2fsck'):
        need(shutil.which(tool), f'Missing image tool: {tool}')
    target, efi = ('arm64-efi', 'BOOTAA64.EFI') if arch == 'aarch64' else ('x86_64-efi', 'BOOTX64.EFI')
    config = work / 'grub-bootstrap.cfg'
    config.write_text('search --no-floppy --label PEDROROOT --set=root\nset prefix=($root)/boot/grub\nconfigfile $prefix/grub.cfg\n')
    run('grub-mkstandalone', '-O', target, '-o', work / efi,
        '--modules=part_gpt fat ext2 normal configfile search search_label linux boot gzio', f'boot/grub/grub.cfg={config}')
    esp, filesystem, mib = work / 'esp.raw', work / 'root.raw', 1048576
    used = int(out('du', '-sx', '--block-size=1', root).split()[0])
    root_mib = max(1024, (used * 13 // 10 + 256 * mib + mib - 1) // mib)
    for path, size in ((esp, 64 * mib), (filesystem, root_mib * mib)):
        with path.open('wb') as stream:
            stream.truncate(size)
    run('mkfs.fat', '-F', '32', '-n', 'PEDROESP', esp)
    run('mmd', '-i', esp, '::/EFI', '::/EFI/BOOT')
    run('mcopy', '-i', esp, work / efi, '::/EFI/BOOT/' + efi)
    run('mkfs.ext4', '-F', '-L', 'PEDROROOT', '-d', root, filesystem)
    run('e2fsck', '-fn', filesystem)
    partial = images / 'pedro.img.partial'
    with partial.open('wb') as stream:
        stream.truncate((root_mib + 66) * mib)
    layout = f'label: gpt\nunit: sectors\nstart=2048,size=131072,type=uefi,name=PEDROESP\nstart=133120,size={root_mib * 2048},type=linux,name=PEDROROOT\n'
    run('sfdisk', partial, input=layout, text=True)
    with partial.open('r+b') as target_file:
        for part, offset in ((esp, mib), (filesystem, 65 * mib)):
            target_file.seek(offset)
            with part.open('rb') as stream:
                shutil.copyfileobj(stream, target_file, 4 * mib)
    run('sfdisk', '--verify', partial)
    partial.replace(images / 'pedro.img')
    print(f'Image: {images / "pedro.img"} ({arch}, GPT/FAT32/ext4)', flush=True)


def main():
    action, src, binary, arch = sys.argv[1:]
    source, build = Path(src).resolve(), Path(binary).resolve()
    check(source, build, arch)
    if action == 'stage' and os.environ.get('PEDRO_PRIVATE_MOUNTS') != '1':
        os.execvpe('unshare', ['unshare', '--mount', '--propagation', 'private', sys.executable,
                            __file__, *sys.argv[1:]], dict(os.environ, PEDRO_PRIVATE_MOUNTS='1'))
    if action != 'check':
        {'stage': stage, 'verify': verify, 'image': image}[action](source, build, arch)


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, OSError, subprocess.CalledProcessError) as error:
        sys.exit(f'Pedro: {error}')
