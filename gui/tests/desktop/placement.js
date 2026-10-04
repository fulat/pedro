const GLib = imports.gi.GLib;
const source = new TextDecoder().decode(GLib.file_get_contents(ARGV[0])[1]).replace(/^\.pragma library\s*/, "");
const place = new Function(source + "\nreturn place;")();
const bounds = {x: 0, y: 0, width: 1600, height: 1000};
const occupied = [];
for (const size of [{width: 900, height: 720}, {width: 480, height: 340}, {width: 900, height: 539}, {width: 480, height: 600}, {width: 900, height: 720}]) {
    const point = place(size, bounds, occupied, {x: 300, y: 100});
    if (point.x < 0 || point.y < 0 || point.x + size.width > 1600 || point.y + size.height > 1000) throw new Error("Window outside screen");
    for (const other of occupied) {
        const overlapWidth = Math.max(0, Math.min(point.x + size.width, other.x + other.width) - Math.max(point.x, other.x));
        const overlapHeight = Math.max(0, Math.min(point.y + size.height, other.y + other.height) - Math.max(point.y, other.y));
        if (overlapWidth * overlapHeight >= Math.min(size.width * size.height, other.width * other.height) * 0.96) throw new Error("Mixed windows cover one another completely");
    }
    occupied.push(Object.assign({}, point, size));
}
const constrained = place({width: 800, height: 600}, {x: -800, y: 0, width: 800, height: 600}, [{x: -800, y: 0, width: 800, height: 600}], {x: -800, y: 0});
if (constrained.x !== -800 || constrained.y !== 0) throw new Error("Constrained secondary screen placement");
print("Mixed folder, image, text and video placement: bounds and partial visibility passed");
