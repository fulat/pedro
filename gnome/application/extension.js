import Gio from 'gi://Gio';
import Shell from 'gi://Shell';
import GLib from 'gi://GLib';
import St from 'gi://St';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

Gio._promisify(Shell.Screenshot.prototype, 'screenshot_stage_to_content');
Gio._promisify(Shell.Screenshot, 'composite_to_stream');

const interfaceXml = `<node>
    <interface name="org.pedro.Applications">
        <method name="Activate"><arg type="s" direction="in" name="id"/></method>
        <method name="GetRunning"><arg type="as" direction="out" name="ids"/></method>
        <method name="Capture"><arg type="i" direction="in" name="x"/><arg type="i" direction="in" name="y"/><arg type="i" direction="in" name="width"/><arg type="i" direction="in" name="height"/><arg type="b" direction="in" name="video"/><arg type="b" direction="in" name="cursor"/><arg type="s" direction="in" name="filename"/><arg type="b" direction="out" name="success"/><arg type="s" direction="out" name="filename"/></method>
        <signal name="CaptureStopped"><arg type="s" name="error"/></signal>
        <method name="StopCapture"><arg type="b" direction="out" name="success"/></method>
    </interface>
</node>`;

// GNOME owns matching, activation, workspace changes and minimized windows.
export default class Applications extends Extension {
    enable() {
        // Wayland ignores Qt's stays-on-bottom hint for ordinary app windows.
        // Keep only Pedro's wallpaper window below applications; never lower Files.
        this._focusSignal = global.display.connect('notify::focus-window',
            () => this._lowerDesktop());
        this._windowSignal = global.display.connect('window-created', () => {
            if (!this._desktopIdle) {
                this._desktopIdle = GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
                    this._desktopIdle = 0;
                    this._lowerDesktop();
                    return GLib.SOURCE_REMOVE;
                });
            }
        });
        this._lowerDesktop();
        this._service = Gio.DBusExportedObject.wrapJSObject(interfaceXml, this);
        this._service.export(Gio.DBus.session, '/org/pedro/Applications');
        this._captureSignal = Gio.DBus.session.signal_subscribe(
            'org.gnome.Shell.Screencast', 'org.gnome.Shell.Screencast', 'Error',
            '/org/gnome/Shell/Screencast', null, Gio.DBusSignalFlags.NONE,
            (connection, sender, path, iface, signal, parameters) => {
                if (this._captureRecording) {
                    this._captureRecording = false;
                    this._service.emit_signal('CaptureStopped',
                        new GLib.Variant('(s)', [parameters.deep_unpack()[1]]));
                }
            });
        this._owner = Gio.bus_own_name_on_connection(Gio.DBus.session,
            'org.pedro.Applications', Gio.BusNameOwnerFlags.NONE, null, null);
    }

    _lowerDesktop() {
        for (const actor of global.get_window_actors()) {
            const window = actor.meta_window;
            const application = (window.get_wm_class() ?? '').toLowerCase();
            if (window.get_title() === 'Pedro OS' &&
                ['pedro', 'pedro_gui', 'pedro-gui'].includes(application)) {
                window.lower();
            }
        }
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

    async _recorderCall(method, argumentsVariant) {
        return await new Promise((resolve, reject) => {
            Gio.DBus.session.call('org.gnome.Shell.Screencast',
                '/org/gnome/Shell/Screencast', 'org.gnome.Shell.Screencast',
                method, argumentsVariant, null, Gio.DBusCallFlags.NONE, -1, null,
                (connection, result) => {
                    try {
                        resolve(connection.call_finish(result).deep_unpack());
                    } catch (error) {
                        reject(error);
                    }
                });
        });
    }

    async CaptureAsync([x, y, width, height, video, cursor, filename], invocation) {
        try {
            if (width <= 0 || height <= 0 || !GLib.path_is_absolute(filename))
                throw new Error('Invalid capture region or destination');
            if (this._captureRecording || Main.screenshotUI.screencast_in_progress)
                throw new Error('A recording is already in progress');
            if (this._captureOwner) {
                Gio.bus_unwatch_name(this._captureOwner);
                this._captureOwner = 0;
            }
            let success;
            let saved = filename;
            if (video) {
                this._captureAlive = true;
                this._captureOwner = Gio.bus_watch_name_on_connection(Gio.DBus.session,
                    invocation.get_sender(), Gio.BusNameWatcherFlags.NONE, null, () => {
                        this._captureAlive = false;
                        if (this._captureRecording) {
                            this._recorderCall('StopScreencast', null).catch(console.error);
                            this._captureRecording = false;
                        }
                    });
                [success, saved] = await this._recorderCall('ScreencastArea',
                    new GLib.Variant('(iiiisa{sv})', [x, y, width, height, filename,
                        {'draw-cursor': new GLib.Variant('b', cursor)}]));
                this._captureRecording = success;
                if (!this._captureAlive && success) {
                    await this._recorderCall('StopScreencast', null);
                    this._captureRecording = false;
                    success = false;
                }
            } else {
                const shooter = new Shell.Screenshot();
                const [content, scale, cursorContent, point, cursorScale] =
                    await shooter.screenshot_stage_to_content();
                const stream = Gio.MemoryOutputStream.new_resizable();
                await Shell.Screenshot.composite_to_stream(content.get_texture(),
                    Math.round(x * scale), Math.round(y * scale), Math.round(width * scale), Math.round(height * scale), scale,
                    cursor ? cursorContent?.get_texture() ?? null : null,
                    point.x * scale, point.y * scale, cursorScale, stream);
                stream.close(null);
                const bytes = stream.steal_as_bytes();
                Gio.File.new_for_path(filename).replace_contents(bytes.get_data(), null, false, Gio.FileCreateFlags.NONE, null);
                St.Clipboard.get_default().set_content(St.ClipboardType.CLIPBOARD, 'image/png', bytes);
                success = true;
            }
            invocation.return_value(new GLib.Variant('(bs)', [success, saved]));
        } catch (error) {
            if (this._captureOwner && !this._captureRecording) {
                Gio.bus_unwatch_name(this._captureOwner);
                this._captureOwner = 0;
            }
            invocation.return_dbus_error('org.pedro.Applications.CaptureFailed', error.message);
        }
    }

    async StopCaptureAsync(params, invocation) {
        try {
            if (!this._captureRecording)
                throw new Error('No Pedro recording is in progress');
            const [success] = await this._recorderCall('StopScreencast', null);
            if (success) {
                this._captureRecording = false;
                if (this._captureOwner) {
                    Gio.bus_unwatch_name(this._captureOwner);
                    this._captureOwner = 0;
                }
            }
            invocation.return_value(new GLib.Variant('(b)', [success]));
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
        if (this._focusSignal) {
            global.display.disconnect(this._focusSignal);
            this._focusSignal = 0;
        }
        if (this._windowSignal) {
            global.display.disconnect(this._windowSignal);
            this._windowSignal = 0;
        }
        if (this._desktopIdle) {
            GLib.Source.remove(this._desktopIdle);
            this._desktopIdle = 0;
        }
        if (this._captureOwner) {
            Gio.bus_unwatch_name(this._captureOwner);
            this._captureOwner = 0;
        }
        if (this._captureSignal) {
            Gio.DBus.session.signal_unsubscribe(this._captureSignal);
            this._captureSignal = 0;
        }
        if (this._captureRecording) {
            this._recorderCall('StopScreencast', null).catch(console.error);
            this._captureRecording = false;
        }
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
