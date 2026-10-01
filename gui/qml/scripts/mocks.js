.pragma library

// Supplies temporary presentation models until PAPI exposes live equivalents.

// Entries rendered by the fixed operating-system navigation rail.
function osNavigationMenuItems() {
    return [
    {
        id: "home",
        name: qsTranslate("Pedro", "shell.navigation.home"),
        icon: "home",
        mode: ""
    },
    {
        id: "files",
        name: qsTranslate("Pedro", "app.files.name"),
        icon: "folder",
        mode: "files"
    },
    {
        id: "apps",
        name: qsTranslate("Pedro", "shell.applications.title"),
        icon: "apps",
        mode: "about"
    },
    {
        id: "messages",
        name: qsTranslate("Pedro", "app.messages.name"),
        icon: "chat",
        mode: "about"
    },
    {
        id: "settings",
        name: qsTranslate("Pedro", "shell.navigation.settings"),
        icon: "settings",
        mode: "system"
    },
    {
        id: "focus",
        name: qsTranslate("Pedro", "shell.navigation.focus"),
        icon: "moon",
        mode: "quick"
    },
    {
        id: "documents",
        name: qsTranslate("Pedro", "shell.navigation.documents"),
        icon: "notes",
        mode: "files"
    },
    {
        id: "display",
        name: qsTranslate("Pedro", "shell.navigation.display"),
        icon: "brightness",
        mode: "quick"
    },
    {
        id: "power",
        name: qsTranslate("Pedro", "shell.navigation.power"),
        icon: "power",
        mode: "system"
    }
]

}
