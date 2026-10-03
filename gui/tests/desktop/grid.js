// Run with: gjs gui/tests/desktop/grid.js gui/qml/scripts/desktop/grid.js
const GLib = imports.gi.GLib;
const ByteArray = imports.byteArray;
const [loaded, contents] = GLib.file_get_contents(ARGV[0]);
if (!loaded) {
    throw new Error("Cannot read desktop grid source");
}
const source = ByteArray.toString(contents).replace(/^\.pragma library\s*/, "");
const Grid = new Function(source + "\nreturn {regions, candidates, placement, intersects, stack};")();
const bounds = {x: 8, y: 8, width: 1264, height: 704};
const item = {width: 106, height: 102, column: 0, row: 0};
const logo = {x: 10, y: -2, width: 52, height: 52};
const menu = {x: 872, y: 2, width: 356, height: 46};
const notification = {x: 1236, y: 2, width: 46, height: 46};
let checks = 0;

function assert(condition, message) {
    ++checks;
    if (!condition) {
        throw new Error(message);
    }
}

function place(target, obstacles, items = [item], occupied = []) {
    return Grid.placement(bounds, obstacles, occupied, items, target, 114, 110, 8);
}

function near(first, second) {
    return Math.abs(first - second) < 0.000001;
}

let result = place({x: 8, y: 8}, []);
assert(near(result[0].x, 8) && near(result[0].y, 8), "Unblocked desktop starts at screen inset");
result = place({x: 62, y: 8}, [logo]);
assert(near(result[0].x, 62) && near(result[0].y, 8), "Beside logo keeps first screen row");
result = place({x: 8, y: 50}, [logo]);
assert(near(result[0].x, 8) && near(result[0].y, 50), "Below logo starts at its bottom clearance");
result = place({x: 1166, y: 48}, [logo, menu, notification]);
assert(near(result[0].x, 1166) && near(result[0].y, 48), "Top-right drop starts below menus, not next global row");
result = place({x: 766, y: 8}, [menu, notification]);
assert(near(result[0].x, 766) && near(result[0].y, 8), "Beside status menu aligns to its left edge");
result = place({x: 8, y: 8}, [menu, notification]);
assert(near(result[0].x, 8) && near(result[0].y, 8), "Distant menu does not move clear screen corner down");

const pair = [item, {width: 106, height: 102, column: 1, row: 0}];
result = place({x: 62, y: 8}, [logo], pair);
assert(result && result.length === 2, "Grouped drag finds a placement");
assert(near(result[0].y, result[1].y) && result[1].x - result[0].x >= 114, "Grouped drag preserves row and gap");
const occupied = [{x: 62, y: 8, width: 106, height: 102}];
result = place({x: 62, y: 8}, [logo], [item], occupied);
assert(result && !Grid.intersects(result[0], occupied[0], 8 - 0.000001), "Occupied icons keep their clearance");
assert(place({x: 8, y: 8}, [bounds]) === null, "Fully blocked desktop has no placement");
assert(Grid.candidates({x: 0, y: 0, width: 70, height: 70}, [], 106, 102, 114, 110).length === 0,
    "Viewport smaller than one icon has no candidates");

// Exercise dock positions, widgets, resized menus, overlapping obstacles and grouped drops.
for (let scenario = 0; scenario < 32; ++scenario) {
    const obstacles = [logo, {x: 700 + scenario * 9, y: 2, width: 200, height: 46},
        {x: 1, y: 220, width: 60, height: 250},
        {x: 400, y: 630, width: 300, height: 82},
        {x: 8, y: 640, width: 180, height: 72}];
    for (const cell of Grid.candidates(bounds, obstacles, 106, 102, 114, 110)) {
        const rectangle = {x: cell.x, y: cell.y, width: 106, height: 102};
        assert(rectangle.x >= bounds.x && rectangle.y >= bounds.y, "Cell respects top/left screen inset");
        assert(rectangle.x + rectangle.width <= bounds.x + bounds.width + 0.000001
            && rectangle.y + rectangle.height <= bounds.y + bounds.height + 0.000001, "Cell respects bottom/right screen inset");
        assert(!obstacles.some(obstacle => Grid.intersects(rectangle, obstacle, -0.000001)), "Cell never overlaps chrome");
    }
    result = place({x: 850, y: 48}, obstacles, pair);
    assert(result && result.every(rectangle => !obstacles.some(obstacle => Grid.intersects(rectangle, obstacle, -0.000001))),
        "Grouped placement avoids all shell obstacles");
}
result = place({x: 1166, y: 48}, [logo, menu, notification],
    [item, {width: 106, height: 102, column: -1, row: 0}]);
assert(result && result[1].x < result[0].x && near(result[0].y, result[1].y),
    "Dragging the rightmost group member preserves icons to its left");
result = place({x: 1166, y: 48}, [logo, menu, notification],
    [item, {width: 106, height: 102, column: 0, row: 1}]);
assert(result && result[1].y - result[0].y >= 110, "Vertical selection keeps the icon gap");
print("Desktop grid: " + checks + " checks passed");

// Exercise the real QML controller functions with shell geometry and model writes.
const controllerPath = ARGV[1] || "gui/qml/controllers/Application.qml";
const [, controllerContents] = GLib.file_get_contents(controllerPath);
const controllerSource = ByteArray.toString(controllerContents);
const functions = controllerSource.match(/^    function [\s\S]*?^    }/gm).join("\n");
const saved = [];
const shortcuts = [];
const context = {
    Grid,
    Qt: {point: (x, y) => ({x, y})},
    Backend: {desktopModel: {organization: "grid", keepAligned: true,
        savePosition: (id, x, y, manual) => saved.push({id, x, y, manual})}},
    desktopShortcuts: {width: 1280, height: 720, cellWidth: 114, cellHeight: 110, cellGap: 8},
    desktopShortcutRepeater: {count: 0, itemAt: index => shortcuts[index]},
    desktopObstacles: [],
    desktopDragItems: [],
    desktopDragAnchor: null,
    desktopDragging: true,
    selectedDesktopIds: [],
    stackDragPending: false
};
const Controller = new Function("context", "with (context) {\n" + functions
    + "\nreturn {snapDesktopDragToGrid, desktopInitialPosition, desktopRestoredPosition, desktopStackPosition, sortDesktop, endDesktopDrag};\n}")(context);

function obstacle(rectangle) {
    return {width: rectangle.width - 16, height: rectangle.height - 16, visible: true,
        mapToItem: () => ({x: rectangle.x + 8, y: rectangle.y + 8})};
}

function shortcut(id, x, y, position) {
    return {app: {id, position}, x, y, width: 106, height: 102, visible: true};
}

const dragged = shortcut("dragged", 1166, 48);
shortcuts.push(dragged);
context.desktopShortcutRepeater.count = shortcuts.length;
context.desktopObstacles = [logo, menu, notification].map(obstacle);
context.selectedDesktopIds = ["dragged"];
context.desktopDragAnchor = dragged;
context.desktopDragItems = [{item: dragged, x: 122, y: 118}];
Controller.snapDesktopDragToGrid();
assert(near(dragged.x, 1166) && near(dragged.y, 48), "Controller drops icon immediately below status menus");
assert(saved.length === 1 && near(saved[0].y, 48), "Controller persists obstacle-relative coordinates");
assert(saved[0].manual === true, "Grid drag updates the manual baseline");
assert(!context.desktopDragging, "Controller ends drag before assigning final coordinates");

context.desktopObstacles = [logo].map(obstacle);
const restored = Controller.desktopRestoredPosition({position: {x: 8, y: 8}}, 0);
assert(near(restored.x, 8) && near(restored.y, 50), "Restoration repairs a blocked position using the nearby logo edge");
context.desktopObstacles = [];
const initial = Controller.desktopInitialPosition(0);
assert(near(initial.x, 8) && near(initial.y, 8), "New grid icons start at the unobstructed screen origin");
dragged.initialPosition = initial;
const second = shortcut("second", 0, 0);
shortcuts.push(second);
context.desktopShortcutRepeater.count = shortcuts.length;
const next = Controller.desktopInitialPosition(1);
assert(!Grid.intersects({x: next.x, y: next.y, width: 106, height: 102},
    {x: initial.x, y: initial.y, width: 106, height: 102}, 8 - 0.000001), "New icons reserve earlier grid cells");

context.Backend.desktopModel.organization = "free";
dragged.x = 321.5;
dragged.y = 234.5;
context.desktopDragging = true;
context.desktopDragAnchor = dragged;
context.desktopDragItems = [{item: dragged, x: 100, y: 100}];
Controller.endDesktopDrag();
assert(near(dragged.x, 321.5) && near(dragged.y, 234.5), "Free mode retains exact dropped coordinates");
assert(near(saved[saved.length - 1].x, 321.5), "Free mode persists exact coordinates");
assert(saved[saved.length - 1].manual === true, "Free drag updates the manual baseline");
context.Backend.desktopModel.organization = "grid";
context.Backend.desktopModel.keepAligned = false;
dragged.x = 333.5;
dragged.y = 222.5;
context.desktopDragItems = [{item: dragged, x: 100, y: 100}];
Controller.endDesktopDrag();
assert(near(dragged.x, 333.5) && near(dragged.y, 222.5), "Grid without Keep aligned still allows unsnapped drops");
print("Desktop controller: integration checks passed; " + checks + " total checks");

const stacks = Grid.stack(bounds, [logo, menu, notification], 106, 102, 114, 110, 8);
assert(near(stacks[0].x, 1166) && near(stacks[0].y, 48), "Stacks start immediately below top menus");
assert(near(stacks[1].x, stacks[0].x) && near(stacks[1].y - stacks[0].y, 110), "Stacks continue down before moving left");
const clearStacks = Grid.stack(bounds, [], 106, 102, 114, 110, 8);
assert(near(clearStacks[0].y, 8), "Unblocked stack column starts at screen inset");
for (let index = 0; index < stacks.length; ++index) {
    assert(![logo, menu, notification].some(obstacle => Grid.intersects(stacks[index], obstacle, -0.000001)), "Stack avoids shell");
    assert(!stacks.slice(0, index).some(other => Grid.intersects(stacks[index], other, 8 - 0.000001)), "Stacks preserve icon spacing");
}
const sidebar = {x: 1150, y: 220, width: 130, height: 80};
const segmented = Grid.stack(bounds, [menu, notification, sidebar], 106, 102, 114, 110, 8);
assert(segmented.some(position => near(position.x, 1166) && near(position.y, 300)), "Stack restarts immediately below a mid-column obstacle");
context.desktopObstacles = [logo, menu, notification].map(obstacle);
context.Backend.desktopModel.organization = "stack";
const beforeStack = saved.length;
const firstStack = Controller.desktopStackPosition(0);
assert(near(firstStack.x, 1166) && near(firstStack.y, 48), "Controller uses menu edge for first stack");
assert(saved.length === beforeStack, "Stack placement does not overwrite saved individual positions");
print("Stack placement: passed; " + checks + " total checks");

// Sorting a free/grid desktop replaces coordinates in model order without changing mode.
context.desktopObstacles = [logo, menu, notification].map(obstacle);
context.Backend.desktopModel.organization = "free";
context.desktopDragItems = [];
context.desktopDragAnchor = null;
context.desktopDragging = false;
const oldSavedCount = saved.length;
Controller.sortDesktop();
assert(context.Backend.desktopModel.organization === "free", "Explicit sorting preserves free organization");
assert(saved.slice(oldSavedCount).every(position => !position.manual), "Automatic sorting does not replace manual baselines");
assert(saved.length === oldSavedCount + shortcuts.length, "Sorting persists every icon in the active layout");
assert(dragged.x >= second.x && (dragged.x > second.x || dragged.y < second.y), "Icon positions follow the ordered model");
assert(!Grid.intersects(dragged, second, 8 - 0.000001), "Sorted icons preserve grid spacing");
context.Backend.desktopModel.organization = "grid";
Controller.sortDesktop();
assert(context.Backend.desktopModel.organization === "grid", "Explicit sorting preserves grid organization");
print("Desktop sorting controller: passed; " + checks + " total checks");

context.Backend.desktopModel.organization = "stack";
context.Backend.desktopModel.groups = [{key: "text", members: [dragged.app.id, second.app.id]}];
context.expandedDesktopStacks = ["text"];
const beforeStackSort = saved.length;
Controller.sortDesktop();
assert(near(dragged.y, 48) && second.y > dragged.y && near(dragged.x, second.x),
    "Sorting expanded stack members respects the model order and menu edge");
assert(saved.length === beforeStackSort, "Sorting stacks preserves individual free/grid layout records");
print("Expanded stack sorting: passed; " + checks + " total checks");
