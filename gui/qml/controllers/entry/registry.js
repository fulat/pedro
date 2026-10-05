.pragma library

var components = [];

function register(component) {
    if (components.indexOf(component) === -1) components.push(component);
}

function unregister(component) {
    components = components.filter(item => item !== component);
}

function find(window, url) {
    return components.find(item => item.visible && item.registeredWindow === window
        && String(item.entry.url) === String(url));
}

function isRenaming(window) {
    return components.some(item => item.registeredWindow === window && item.renaming);
}
