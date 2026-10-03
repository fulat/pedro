// Run with: gjs gnome/application/tests/glass.js gnome/application/extension.js
const GLib = imports.gi.GLib;
const source = new TextDecoder().decode(GLib.file_get_contents(ARGV[0])[1])
    .replace(/^import .*;$/gm, '')
    .replace('export default class Applications extends Extension', 'class Applications extends Extension');
const actors = [];
let nextSignal = 1;
let ownerChanged;
let busCaller = 42;
let checks = 0;
function assert(value, message) {
    if (!value) throw new Error(message);
    checks++;
}
function emitter() {
    const handlers = new Map();
    return {
        connect(name, callback) { const id = nextSignal++; handlers.set(id, [name, callback]); return id; },
        disconnect(id) { handlers.delete(id); },
        emit(name, ...args) { for (const [signal, callback] of handlers.values()) if (signal === name) callback(this, ...args); }
    };
}
function actor(pid, title) {
    const window = Object.assign(emitter(), {get_pid: () => pid, get_title: () => title,
        setTitle(value) { title = value; this.emit('notify::title'); }});
    return Object.assign(emitter(), {meta_window: window, effects: [],
        add_effect_with_name(name, effect) { this.effects.push(effect); },
        remove_effect(effect) { this.effects = this.effects.filter(value => value !== effect); }});
}
const Gio = {
    DBusExportedObject: {wrapJSObject: () => ({export() {}, unexport() {}})},
    DBus: {session: {
        signal_subscribe(...args) { ownerChanged = args.at(-1); return 1; },
        signal_unsubscribe() {},
        call(...args) { args.at(-1)(this, {}); },
        call_finish() { return {deep_unpack: () => [busCaller]}; }
    }},
    DBusSignalFlags: {NONE: 0}, DBusCallFlags: {NONE: 0}, BusNameOwnerFlags: {NONE: 0},
    bus_own_name_on_connection: () => 1, bus_unown_name() {}
};
const Shell = {BlurMode: {BACKGROUND: 'background'}, BlurEffect: class {
    constructor(properties) { Object.assign(this, properties); }
    set_radius(value) { this.radius = value; }
}};
const shell = {window_manager: emitter(), get_window_actors: () => actors};
const Integration = new Function('Gio', 'GLib', 'Shell', 'Extension', 'global', source + '\nreturn Applications;')(Gio, GLib, Shell, class {}, shell);
const own = actor(42, 'Files');
const foreign = actor(99, 'Files');
actors.push(own, foreign);
const integration = new Integration();
integration.enable();
let replied = false;
integration.SetGlassAsync(['Files'], {get_sender: () => ':1.42', return_value() { replied = true; }, return_dbus_error(name, message) { throw new Error(name + message); }});
assert(replied && integration.GetGlass() === 1, 'Registration applies to the caller window');
assert(foreign.effects.length === 0, 'Other processes with the same title remain untouched');
assert(own.effects[0].mode === 'background' && own.effects[0].radius === 64, 'Use compositor background blur, preserving foreground content');
own.meta_window.setTitle('Other');
assert(integration.GetGlass() === 0, 'Changing the title removes the effect');
own.meta_window.setTitle('Files');
assert(integration.GetGlass() === 1, 'Returning to the registered title restores the effect');
const another = actor(42, 'Files');
shell.window_manager.emit('map', another);
assert(integration.GetGlass() === 2, 'New matching windows are handled');
ownerChanged(null, null, null, null, null, {deep_unpack: () => [':1.42', ':1.42', '']});
assert(integration.GetGlass() === 0, 'Disconnecting the client removes all its effects');
integration.disable();
assert(own.effects.length === 0 && another.effects.length === 0, 'Disabling leaves no effects');
print(`Native glass lifecycle: ${checks} checks passed`);
