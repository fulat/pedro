.pragma library

function colors(mode) {
    const light = mode === "light";
    return {
        light: light,
        surface: "transparent",
        sidebar: light ? "#32e6edf7" : "#30131b29",
        card: light ? "#65ffffff" : "#65304156",
        ink: light ? "#10164d" : "#eef3ff",
        muted: light ? "#536baa" : "#a5b7db",
        line: light ? "#30919cad" : "#387f90a8",
        accent: "#0877ff",
        hover: light ? "#16707780" : "#18ffffff",
        selected: light ? "#b3cde3ff" : "#aa304e76",
        banner: light ? "#e7f2ff" : "#2b4262"
    };
}
