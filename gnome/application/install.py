#!/usr/bin/env python3
"""Install and enable the Pedro GNOME application integration for this user."""
import os
from pathlib import Path
import shutil
import subprocess

from gi.repository import Gio


def main():
    data = Path(os.environ.get('XDG_DATA_HOME', str(Path.home() / '.local/share')))
    if not data.is_absolute():
        raise SystemExit('XDG_DATA_HOME must be absolute')
    uuid = 'applications@pedro'
    destination = data / 'gnome-shell/extensions' / uuid
    destination.mkdir(parents=True, exist_ok=True)
    for name in ('extension.js', 'metadata.json'):
        shutil.copyfile(Path(__file__).parent / name, destination / name)
    settings = Gio.Settings.new('org.gnome.shell')
    enabled = settings.get_strv('enabled-extensions')
    if uuid not in enabled:
        enabled.append(uuid)
        if not settings.set_strv('enabled-extensions', enabled):
            raise SystemExit('Cannot enable Pedro GNOME integration')
    disabled = settings.get_strv('disabled-extensions')
    if uuid in disabled:
        settings.set_strv('disabled-extensions', [value for value in disabled if value != uuid])
    Gio.Settings.sync()
    result = subprocess.run(['gdbus', 'call', '--session', '--dest', 'org.gnome.Shell',
        '--object-path', '/org/gnome/Shell', '--method',
        'org.gnome.Shell.Extensions.EnableExtension', uuid], capture_output=True, text=True)
    print(f'Installed: {destination}')
    if result.returncode != 0 or 'true' not in result.stdout:
        print('GNOME must discover the new extension: log out and back in once.')
    if settings.get_boolean('disable-user-extensions'):
        print('GNOME user extensions are disabled; enable them to use this integration.')


if __name__ == '__main__':
    main()
