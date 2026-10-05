#!/usr/bin/env python3
"""Install and enable the Pedro GNOME application integration for this user."""
import os
from pathlib import Path
import shutil
import subprocess
import xml.etree.ElementTree as ElementTree

from gi.repository import Gio, GLib


def main():
    data = Path(os.environ.get('XDG_DATA_HOME', str(Path.home() / '.local/share')))
    if not data.is_absolute():
        raise SystemExit('XDG_DATA_HOME must be absolute')
    uuid = 'applications@pedro'
    destination = data / 'gnome-shell/extensions' / uuid
    destination.mkdir(parents=True, exist_ok=True)
    files = ('extension.js', 'metadata.json')
    changed = any((destination / name).is_file() and (destination / name).read_bytes() !=
        (Path(__file__).parent / name).read_bytes() for name in files)
    for name in files:
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
    if changed:
        print('Updated GNOME integration: log out and back in to load the new code.')
    # Installed files can match while GNOME still runs a cached older version.
    try:
        reply = Gio.bus_get_sync(Gio.BusType.SESSION, None).call_sync('org.pedro.Applications',
            '/org/pedro/Applications', 'org.freedesktop.DBus.Introspectable',
            'Introspect', None, GLib.VariantType.new('(s)'),
            Gio.DBusCallFlags.NONE, 3000, None)
        interface = ElementTree.fromstring(reply.unpack()[0]).find(
            "interface[@name='org.pedro.Applications']")
        methods = {method.get('name') for method in interface.findall('method')} if interface is not None else set()
        if 'PlaceWindow' in methods:
            print('Pedro stack window placement integration is active.')
        else:
            print('Stack window placement needs a GNOME logout and login to load PlaceWindow.')
        if {'PlaceWindowIdentity', 'ActivateWindowIdentity'}.issubset(methods):
            print('Pedro stable window identity integration is active.')
        else:
            print('Stable viewer identity needs a GNOME logout and login to load the new methods.')
        if 'ActivateWindow' in methods:
            print('Pedro viewer focus integration is active.')
        else:
            print('Viewer focus integration needs a GNOME logout and login to load ActivateWindow.')
        if {'Capture', 'StopCapture'}.issubset(methods):
            print('Screen capture integration is active: Capture and StopCapture are available.')
        else:
            print('GNOME is still running an older Pedro integration without capture methods.')
            print('Log out and back in to load the installed integration; restarting Pedro is not enough.')
    except GLib.Error:
        print('Pedro capture service is not active yet: log out and back in to load it.')
    if settings.get_boolean('disable-user-extensions'):
        print('GNOME user extensions are disabled; enable them to use this integration.')


if __name__ == '__main__':
    main()
