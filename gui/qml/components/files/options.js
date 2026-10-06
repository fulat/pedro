.pragma library

function views() {
    return [{key: "grid", icon: "grid", label: "files.view.grid"},
            {key: "list", icon: "list", label: "files.view.list"},
            {key: "columns", icon: "columns", label: "files.view.columns"},
            {key: "mixed", icon: "mixed", label: "files.view.mixed"}];
}

function sorting() {
    return [{key: "name", icon: "sort", label: "files.sample.name"},
            {key: "type", icon: "file", label: "files.sample.type"},
            {key: "size", icon: "size", label: "files.sample.size"},
            {key: "modified", icon: "calendar", label: "files.sample.modified"}];
}
