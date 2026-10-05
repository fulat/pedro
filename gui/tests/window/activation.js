const GLib = imports.gi.GLib;
const source = new TextDecoder().decode(GLib.file_get_contents(ARGV[0])[1])
    .replace(/^import .*$/gm, "").replace("export default class Applications", "class Applications");
let actors = [];
const activations = [];
const shell = {get_window_actors: () => actors, display: {get_current_time_roundtrip: () => 1234}};
const Gio = {_promisify: () => {}};
const Shell = {Screenshot: {prototype: {}}};
const Main = {activateWindow: (window, timestamp) => activations.push({window, timestamp})};
const Applications = new Function("Gio", "Shell", "GLib", "St", "Main", "Extension", "global", source + "\nreturn Applications;")(
    Gio, Shell, {Variant: class { constructor(type, value) { this.value = value; } deep_unpack() { return this.value; } },
        timeout_add: (priority, interval, callback) => { for (let i = 0; i < 25; ++i) if (!callback()) break; },
        SOURCE_REMOVE: false, SOURCE_CONTINUE: true}, {}, Main, class {}, shell);
const service = new Applications();
const target = {get_pid: () => 123, get_title: () => "Video.mp4", unminimize: () => {}, unset_demands_attention: () => {}};
const foreign = Object.assign({}, target, {get_pid: () => 456});
actors = [{meta_window: foreign}, {meta_window: target}];
if (!service.ActivateWindow(123, "Video.mp4") || activations.length !== 1 || activations[0].window !== target || activations[0].timestamp !== 1234)
    throw new Error("Selected viewer activation with fresh timestamp failed");
actors.push({meta_window: Object.assign({}, target)});
if (service.ActivateWindow(123, "Video.mp4") || activations.length !== 1)
    throw new Error("Ambiguous filenames activate another viewer");
if (service.ActivateWindow(123, "missing") || activations.length !== 1)
    throw new Error("Missing viewer activation must fall back");
print("GNOME viewer activation: process ownership, current timestamp and ambiguous-name fallback passed");

const bounds = {x: 0, y: 0, width: 1600, height: 1000};
const windows = [1, 2, 3, 4].map(id => {
    const rect = {x: 350, y: 140, width: id === 4 ? 480 : 900, height: id === 4 ? 340 : 720};
    return {get_pid: () => 123, get_title: () => id === 4 ? "Photo.png" : "Files",
        get_stable_sequence: () => id, get_frame_rect: () => rect,
        get_work_area_current_monitor: () => bounds,
        move_frame: (user, x, y) => { rect.x = x; rect.y = y; }};
});
actors = windows.map(meta_window => ({meta_window}));
const registered = [];
for (const title of ["Files", "Files", "Files", "Photo.png"]) {
    let success = false;
    service.PlaceWindowIdentityAsync([123, title, "Pedro OS"], {return_value: result => { success = result.value[0]; registered.push(success); }});
    if (!success) throw new Error("Mapped stack window was not placed");
}
if (registered.join(",") !== "1,2,3,4") throw new Error("Placement must return the assigned stable window identities");
const origins = new Set(windows.map(window => { const rect = window.get_frame_rect(); return `${rect.x}:${rect.y}`; }));
if (origins.size !== 4) throw new Error("GNOME placed stack folders and viewer at identical origins");
print("GNOME placement: three same-title folders and an image viewer get distinct actual frame positions");

for (const window of windows) {
    window.unminimize = () => {};
    window.unset_demands_attention = () => {};
}
if (!service.ActivateWindowIdentity(123, 2) || activations[activations.length - 1].window !== windows[1])
    throw new Error("Stable identity did not focus the second same-title folder");
if (service.ActivateWindowIdentity(456, 2) || service.ActivateWindowIdentity(123, 99))
    throw new Error("Stable identity ignored process ownership or lifecycle");
print("GNOME stable identity: duplicate titles focus the requested window, foreign and closed windows are rejected");

actors.push({meta_window: {...windows[0], get_stable_sequence: () => 5}});
let legacyPlaced = false;
service.PlaceWindowAsync([123, "Files", "Pedro OS"], {return_value: result => { legacyPlaced = result.deep_unpack()[0]; }});
if (!legacyPlaced) throw new Error("Legacy placement compatibility failed");
print("GNOME placement identity registration and legacy compatibility passed");
