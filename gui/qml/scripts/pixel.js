.pragma library

// Converts a logical length to a conservative physical pixel allocation.
function physical(logical, ratio) {
    return Math.max(1, Math.ceil(logical * Math.max(1, ratio)))
}

// Aligns a logical coordinate to the active device pixel grid.
function align(logical, ratio) {
    const scale = Math.max(1, ratio)
    return Math.round(logical * scale) / scale
}
