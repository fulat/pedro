import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import Shell from 'gi://Shell';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

const interfaceXml = `<node>
    <interface name="org.pedro.Applications">
        <method name="Activate"><arg type="s" direction="in" name="id"/></method>
        <method name="GetRunning"><arg type="as" direction="out" name="ids"/></method>
        <method name="SetGlass"><arg type="s" direction="in" name="title"/></method>
        <method name="GetGlass"><arg type="u" direction="out" name="count"/></method>
    </interface>
</node>`;

// GNOME owns matching, activation, workspace changes and minimized windows.
export default class Applications extends Extension {
    enable() {
        this._clients = new Map();
        this._actors = new Map();
        this._mapSignal = global.window_manager.connect('map', (_manager, actor) => this._trackActor(actor));
        for (const actor of global.get_window_actors())
            this._trackActor(actor);
        this._nameSignal = Gio.DBus.session.signal_subscribe('org.freedesktop.DBus',
            'org.freedesktop.DBus', 'NameOwnerChanged', '/org/freedesktop/DBus', null,
            Gio.DBusSignalFlags.NONE, (_connection, _sender, _path, _interface, _signal, parameters) => {
                const [name, , owner] = parameters.deep_unpack();
                if (!owner && this._clients.delete(name))
                    this._syncActors();
            });
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

    GetRunning() {
        return Shell.AppSystem.get_default().get_running()
            .filter(application => application.get_windows().length > 0)
            .map(application => application.get_id());
    }

    // Resolve the caller through the bus instead of trusting a client-supplied PID.
    // A client can only request glass for its own windows with this title.
    SetGlassAsync([title], invocation) {
        if (!title || title.length > 512) {
            invocation.return_dbus_error('org.pedro.Applications.InvalidTitle', 'Invalid window title');
            return;
        }
        const sender = invocation.get_sender();
        Gio.DBus.session.call('org.freedesktop.DBus', '/org/freedesktop/DBus',
            'org.freedesktop.DBus', 'GetConnectionUnixProcessID', new GLib.Variant('(s)', [sender]),
            new GLib.VariantType('(u)'), Gio.DBusCallFlags.NONE, -1, null, (connection, result) => {
                try {
                    const [pid] = connection.call_finish(result).deep_unpack();
                    if (!this._clients)
                        throw new Error('Pedro integration was disabled');
                    const client = this._clients.get(sender) || {pid, titles: new Set()};
                    client.titles.add(title);
                    this._clients.set(sender, client);
                    this._syncActors();
                    invocation.return_value(new GLib.Variant('()', []));
                } catch (error) {
                    invocation.return_dbus_error('org.pedro.Applications.GlassError', error.message);
                }
            });
    }

    GetGlass() {
        return [...this._actors.values()].filter(record => record.effect !== null).length;
    }

    _trackActor(actor) {
        if (this._actors.has(actor))
            return;
        const window = actor.meta_window;
        if (!window)
            return;
        const record = {window, effect: null};
        record.titleSignal = window.connect('notify::title', () => this._syncActor(actor));
        record.destroySignal = actor.connect('destroy', () => {
            window.disconnect(record.titleSignal);
            this._actors.delete(actor);
        });
        this._actors.set(actor, record);
        this._syncActor(actor);
    }

    _syncActors() {
        for (const actor of this._actors.keys())
            this._syncActor(actor);
    }

    _syncActor(actor) {
        const record = this._actors.get(actor);
        const enabled = [...this._clients.values()].some(client =>
            client.pid === record.window.get_pid() && client.titles.has(record.window.get_title()));
        if (enabled && !record.effect) {
            const effect = new Shell.BlurEffect({mode: Shell.BlurMode.BACKGROUND, brightness: 1.0});
            if (typeof effect.set_radius === 'function')
                effect.set_radius(64);
            else
                effect.sigma = 32;
            actor.add_effect_with_name('pedro-glass', effect);
            record.effect = effect;
        } else if (!enabled && record.effect) {
            actor.remove_effect(record.effect);
            record.effect = null;
        }
    }

    disable() {
        if (this._mapSignal) {
            global.window_manager.disconnect(this._mapSignal);
            this._mapSignal = 0;
        }
        if (this._nameSignal) {
            Gio.DBus.session.signal_unsubscribe(this._nameSignal);
            this._nameSignal = 0;
        }
        for (const [actor, record] of this._actors) {
            if (record.effect)
                actor.remove_effect(record.effect);
            record.window.disconnect(record.titleSignal);
            actor.disconnect(record.destroySignal);
        }
        this._actors = null;
        this._clients = null;
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
