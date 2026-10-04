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
    Gio, Shell, {}, {}, Main, class {}, shell);
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
