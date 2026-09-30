.pragma library

// Supplies temporary presentation models until PAPI exposes live equivalents.

// Applications pinned permanently to the dock.
const pinnedApps = [
    {
        id: "files",
        name: "Archivos",
        icon: "folder"
    },
    {
        id: "browser",
        name: "Navegador",
        icon: "browser"
    },
    {
        id: "terminal",
        name: "Terminal",
        icon: "terminal"
    },
    {
        id: "music",
        name: "Música",
        icon: "music"
    },
    {
        id: "photos",
        name: "Fotos",
        icon: "photos"
    }
]

// Applications currently represented in the recent section of the dock.
const recentApps = [
    {
        id: "chat",
        name: "Mensajes",
        icon: "chat"
    },
    {
        id: "notes",
        name: "Notas",
        icon: "notes"
    },
    {
        id: "code",
        name: "Código",
        icon: "code"
    }
]

// Shortcuts and initial grid positions shown on the desktop.
const desktopShortcutRepeaterItems = [
    {
        id: "projects",
        name: "Proyectos",
        icon: "folder",
        mode: "files",
        column: 0,
        row: 0
    },
    {
        id: "notes",
        name: "Notas",
        icon: "notes",
        mode: "about",
        column: 1,
        row: 0
    },
    {
        id: "wallpaper",
        name: "Wallpaper.jpg",
        icon: "image",
        mode: "about",
        column: 2,
        row: 0
    },
    {
        id: "designs",
        name: "Diseños",
        icon: "folder",
        mode: "files",
        column: 3,
        row: 0
    }
]

// Entries rendered by the fixed operating-system navigation rail.
const osNavigationMenuItems = [
    {
        id: "home",
        name: "Inicio",
        icon: "home",
        mode: ""
    },
    {
        id: "files",
        name: "Archivos",
        icon: "folder",
        mode: "files"
    },
    {
        id: "apps",
        name: "Aplicaciones",
        icon: "apps",
        mode: "about"
    },
    {
        id: "messages",
        name: "Mensajes",
        icon: "chat",
        mode: "about"
    },
    {
        id: "settings",
        name: "Configuración",
        icon: "settings",
        mode: "system"
    },
    {
        id: "focus",
        name: "Concentración",
        icon: "moon",
        mode: "quick"
    },
    {
        id: "documents",
        name: "Documentos",
        icon: "notes",
        mode: "files"
    },
    {
        id: "display",
        name: "Pantalla",
        icon: "brightness",
        mode: "quick"
    },
    {
        id: "power",
        name: "Energía",
        icon: "power",
        mode: "system"
    }
]
