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
        <method name="ActivateWindow"><arg type="u" direction="in" name="pid"/><arg type="s" direction="in" name="title"/><arg type="b" direction="out" name="success"/></method>
        <method name="ActivateWindowIdentity"><arg type="u" direction="in" name="pid"/><arg type="u" direction="in" name="identity"/><arg type="b" direction="out" name="success"/></method>
        <method name="PlaceWindowIdentity"><arg type="u" direction="in" name="pid"/><arg type="s" direction="in" name="title"/><arg type="s" direction="in" name="shellTitle"/><arg type="u" direction="out" name="identity"/></method>
        <method name="PlaceWindow"><arg type="u" direction="in" name="pid"/><arg type="s" direction="in" name="title"/><arg type="s" direction="in" name="shellTitle"/><arg type="b" direction="out" name="success"/></method>
        <method name="GetRunning"><arg type="as" direction="out" name="ids"/></method>
        <method name="Capture"><arg type="i" direction="in" name="x"/><arg type="i" direction="in" name="y"/><arg type="i" direction="in" name="width"/><arg type="i" direction="in" name="height"/><arg type="b" direction="in" name="video"/><arg type="b" direction="in" name="cursor"/><arg type="s" direction="in" name="filename"/><arg type="b" direction="out" name="success"/><arg type="s" direction="out" name="filename"/></method>
        <signal name="CaptureStopped"><arg type="s" name="error"/></signal>
        <method name="StopCapture"><arg type="b" direction="out" name="success"/></method>
    </interface>
</node>`;

// GNOME owns matching, activation, workspace changes and minimized windows.
export default class Applications extends Extension {
    enable() {
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

    Activate(id) {
        const application = Shell.AppSystem.get_default().lookup_app(id);
        if (!application)
            throw new Error(`Application is not installed: ${id}`);

        // D-Bus requests have no Shell input event. A stale event timestamp makes
        // Mutter request attention instead of focusing the existing window.
        const timestamp = global.display.get_current_time_roundtrip();
        application.activate_full(-1, timestamp);
    }

    ActivateWindow(pid, title) {
        const matches = global.get_window_actors().map(actor => actor.meta_window)
            .filter(window => window.get_pid() === pid && window.get_title() === title);
        // A duplicate basename must never activate an unrelated Pedro viewer.
        if (matches.length !== 1)
            return false;
        const window = matches[0];
        const timestamp = global.display.get_current_time_roundtrip();
        window.unminimize();
        window.unset_demands_attention();
        Main.activateWindow(window, timestamp);
        return true;
    }

    ActivateWindowIdentity(pid, identity) {
        const window = global.get_window_actors().map(actor => actor.meta_window)
            .find(window => window.get_pid() === pid && window.get_stable_sequence() === identity);
        if (!window) return false;
        window.unminimize();
        window.unset_demands_attention();
        Main.activateWindow(window, global.display.get_current_time_roundtrip());
        return true;
    }

    PlaceWindowAsync(arguments_, invocation) {
        this.PlaceWindowIdentityAsync(arguments_, {
            return_value: result => invocation.return_value(new GLib.Variant('(b)', [result.deep_unpack()[0] !== 0]))});
    }

    PlaceWindowIdentityAsync([pid, title, shellTitle], invocation) {
        let attempts = 0;
        const place = () => {
            const windows = global.get_window_actors().map(actor => actor.meta_window)
                .filter(window => window.get_pid() === pid && window.get_title() !== shellTitle);
            const live = new Set(windows.map(window => window.get_stable_sequence()));
            this._windowPlacements ??= new Map();
            const placed = new Set([...(this._windowPlacements.get(pid) || [])].filter(id => live.has(id)));
            this._windowPlacements.set(pid, placed);
            const matches = windows.filter(window => window.get_title() === title && !placed.has(window.get_stable_sequence()))
                .sort((a, b) => a.get_stable_sequence() - b.get_stable_sequence());
            if (!matches.length) return false;
            const window = matches[0];
            const rect = window.get_frame_rect();
            if (rect.width <= 0 || rect.height <= 0) return false;
            const bounds = window.get_work_area_current_monitor();
            const occupied = windows.filter(other => other !== window).map(other => other.get_frame_rect())
                .filter(other => other.width > 0 && other.height > 0);
            const anchor = occupied.length ? occupied[occupied.length - 1] : rect;
            let best = {x: rect.x, y: rect.y};
            let bestScore = Infinity;
            for (let step = 1; step <= 64 && occupied.length; ++step) {
                const ring = Math.ceil(step / 4);
                const direction = (step - 1) % 4;
                const point = {
                    x: Math.round(Math.max(bounds.x, Math.min(anchor.x + (direction < 2 ? 1 : -1) * ring * 32, bounds.x + bounds.width - rect.width))),
                    y: Math.round(Math.max(bounds.y, Math.min(anchor.y + (direction % 2 === 0 ? 1 : -1) * ring * 28, bounds.y + bounds.height - rect.height)))};
                let score = 0;
                for (const other of occupied) {
                    const width = Math.max(0, Math.min(point.x + rect.width, other.x + other.width) - Math.max(point.x, other.x));
                    const height = Math.max(0, Math.min(point.y + rect.height, other.y + other.height) - Math.max(point.y, other.y));
                    const covered = width * height / Math.min(rect.width * rect.height, other.width * other.height);
                    const distance = Math.max(Math.abs(point.x - other.x), Math.abs(point.y - other.y));
                    score += Math.max(0, covered - 0.96) + Math.max(0, 24 - distance) / 24;
                }
                if (score < bestScore) { best = point; bestScore = score; }
                if (score === 0) break;
            }
            window.move_frame(true, best.x, best.y);
            placed.add(window.get_stable_sequence());
            return window.get_stable_sequence();
        };
        const finish = identity => invocation.return_value(new GLib.Variant('(u)', [identity || 0]));
        const identity = place();
        if (identity) { finish(identity); return; }
        // Qt can request placement before Mutter has mapped the new surface.
        GLib.timeout_add(GLib.PRIORITY_DEFAULT, 20, () => {
            const identity = place();
            if (identity) { finish(identity); return GLib.SOURCE_REMOVE; }
            if (++attempts >= 25) { finish(false); return GLib.SOURCE_REMOVE; }
            return GLib.SOURCE_CONTINUE;
        });
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
