#!/usr/bin/env python3
"""Exercise the GNOME bridge with isolated screen and recorder fixtures."""
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text()
for line in ("import Shell from 'gi://Shell';", "import St from 'gi://St';",
             "import * as Main from 'resource:///org/gnome/shell/ui/main.js';",
             "import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';"):
    source = source.replace(line, '')
source = source.replace('export default class Applications', 'class Applications')
fixture = r"""
class Extension {}
let clipboard = false;
let composition;
const Main = {screenshotUI: {screencast_in_progress: false}};
const St = {ClipboardType: {CLIPBOARD: 1}, Clipboard: {get_default() {
    return {set_content() { clipboard = true; }};
}}};
const Shell = {Screenshot: class {
    async screenshot_stage_to_content() {
        return [{get_texture() { return 'screen'; }}, 2,
            {get_texture() { return 'cursor'; }}, {x: 25, y: 35}, 1];
    }
    static async composite_to_stream(...args) {
        composition = args;
        args.at(-1).write_all(new Uint8Array([1, 2, 3]), null);
    }
}};
"""
# Import Gio first so the fixture can replace only the Shell-specific promisifier.
source = source.replace("Gio._promisify(Shell.Screenshot.prototype, 'screenshot_stage_to_content');", '')
source = source.replace("Gio._promisify(Shell.Screenshot, 'composite_to_stream');", '')
tests = r"""
Gio.bus_watch_name_on_connection = () => 1;
Gio.bus_unwatch_name = () => {};
const info = Gio.DBusNodeInfo.new_for_xml(interfaceXml).interfaces[0];
if (!info.lookup_method('Capture') || !info.lookup_method('StopCapture'))
    throw new Error('Missing capture interface');
const bridge = new Applications();
let lowered = [];
globalThis.global = {get_window_actors() {
    return [
        {meta_window: {get_wm_class() { return 'Pedro'; }, get_title() { return 'Pedro OS'; }, lower() { lowered.push('desktop'); }}},
        {meta_window: {get_wm_class() { return 'Pedro'; }, get_title() { return 'Files'; }, lower() { lowered.push('files'); }}},
        {meta_window: {get_wm_class() { return 'ChatGPT'; }, get_title() { return 'ChatGPT'; }, lower() { lowered.push('external'); }}}
    ];
}};
bridge._lowerDesktop();
if (lowered.length !== 1 || lowered[0] !== 'desktop')
    throw new Error('Desktop stacking must not lower Files or external applications');

let result;
const invocation = {
    get_sender() { return ':1.1000'; },
    return_value(value) { result = value.deep_unpack(); },
    return_dbus_error(name, message) { result = `${name}: ${message}`; },
};
const file = ARGV[0];
await bridge.CaptureAsync([10, 20, 300, 200, false, true, file], invocation);
if (!result[0] || result[1] !== file || !clipboard || composition[1] !== 20 || composition[3] !== 600 || composition[6] !== 'cursor')
    throw new Error('Image region, cursor, scale, clipboard or destination failed');
await bridge.CaptureAsync([10, 20, 300, 200, false, false, file], invocation);
if (composition[6] !== null) throw new Error('Pointer hiding failed');
bridge._recorderCall = async (method, args) => {
    if (method === 'ScreencastArea') return [true, `${args.deep_unpack()[4]}.mp4`];
    if (method === 'StopScreencast') return [true];
    throw new Error('Unexpected recorder action');
};
await bridge.CaptureAsync([10, 20, 300, 200, true, false, file], invocation);
if (!result[0] || !result[1].endsWith('.mp4') || !bridge._captureRecording)
    throw new Error('Recording result or state failed');
await bridge.StopCaptureAsync([], invocation);
if (!result[0] || bridge._captureRecording) throw new Error('Stop failed');
await bridge.CaptureAsync([0, 0, 0, 100, false, false, file], invocation);
if (typeof result !== 'string' || !result.includes('CaptureFailed'))
    throw new Error('Invalid region was not rejected');
print('PASS: GNOME image region, scale, pointer, clipboard, recording filename, stop and errors');
"""
Path(sys.argv[2]).write_text(fixture + source + tests)
