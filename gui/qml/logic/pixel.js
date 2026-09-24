.pragma library

function physical(logical, ratio) {
    return Math.max(1, Math.ceil(logical * Math.max(1, ratio)))
}

function align(logical, ratio) {
    const scale = Math.max(1, ratio)
    return Math.round(logical * scale) / scale
}
