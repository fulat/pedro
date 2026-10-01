.pragma library

function colors(mode) {
    const light = mode === "light";
    return {
        light: light,
        surface: light ? "#f9fbff" : "#202735",
        sidebar: light ? "#f0f5fd" : "#242e40",
        card: light ? "#ffffff" : "#283345",
        ink: light ? "#10164d" : "#eef3ff",
        muted: light ? "#536baa" : "#a5b7db",
        line: light ? "#e5ebf6" : "#3a465e",
        accent: "#0877ff",
        selected: light ? "#dcecff" : "#30486c",
        banner: light ? "#e7f2ff" : "#2b4262"
    };
}
