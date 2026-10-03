import Gio from 'gi://Gio';
import Shell from 'gi://Shell';
import GLib from 'gi://GLib';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

const interfaceXml = `<node>
    <interface name="org.pedro.Applications">
        <method name="Activate"><arg type="s" direction="in" name="id"/></method>
        <method name="GetRunning"><arg type="as" direction="out" name="ids"/></method>
        <method name="SetCaptureVisible"><arg type="b" direction="in" name="visible"/><arg type="b" direction="out" name="visible"/></method>
    </interface>
</node>`;

// GNOME owns matching, activation, workspace changes and minimized windows.
export default class Applications extends Extension {
    enable() {
        this._service = Gio.DBusExportedObject.wrapJSObject(interfaceXml, this);
        this._service.export(Gio.DBus.session, '/org/pedro/Applications');
        this._owner = Gio.bus_own_name_on_connection(Gio.DBus.session,
            'org.pedro.Applications', Gio.BusNameOwnerFlags.NONE, null, null);
    }

    Activate(id) {
        const application = Shell.AppSystem.get_default().lookup_app(id);
        if (!application)
            throw new Error(`Application is not installed: ${id}`);

        // D-Bus requests have no Shell input event. A stale event timestamp makes
        // Mutter request attention instead of focusing the existing window.
        const timestamp = global.display.get_current_time_roundtrip();
        application.activate_full(-1, timestamp);
    }

    async SetCaptureVisibleAsync([visible], invocation) {
        try {
            if (visible)
                await Main.screenshotUI.open();
            else
                Main.screenshotUI.close(true);
            invocation.return_value(new GLib.Variant('(b)', [Main.screenshotUI.visible]));
        } catch (error) {
            invocation.return_dbus_error('org.pedro.Applications.CaptureFailed', error.message);
        }
    }

    GetRunning() {
        return Shell.AppSystem.get_default().get_running()
            .filter(application => application.get_windows().length > 0)
            .map(application => application.get_id());
    }

    disable() {
        if (this._service) {
            this._service.unexport();
            this._service = null;
        }
        if (this._owner) {
            Gio.bus_unown_name(this._owner);
            this._owner = 0;
        }
    }
}
