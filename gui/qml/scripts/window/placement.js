.pragma library

function place(size, bounds, occupied, origin) {
    function clamp(point) {
        return {x: Math.round(Math.max(bounds.x, Math.min(point.x, bounds.x + bounds.width - size.width))),
            y: Math.round(Math.max(bounds.y, Math.min(point.y, bounds.y + bounds.height - size.height)))};
    }
    if (!occupied.length) return clamp(origin);
    const anchor = occupied[occupied.length - 1];
    let best = clamp(origin);
    let bestScore = Infinity;
    // Small offsets first; widen the search when mixed window sizes would hide a window completely.
    for (let step = 1; step <= 64; ++step) {
        const ring = Math.ceil(step / 4);
        const direction = (step - 1) % 4;
        const point = clamp({x: anchor.x + (direction < 2 ? -1 : 1) * ring * 32,
            y: anchor.y + (direction % 2 === 0 ? 1 : -1) * ring * 28});
        let score = 0;
        for (const other of occupied) {
            const width = Math.max(0, Math.min(point.x + size.width, other.x + other.width) - Math.max(point.x, other.x));
            const height = Math.max(0, Math.min(point.y + size.height, other.y + other.height) - Math.max(point.y, other.y));
            const covered = width * height / Math.min(size.width * size.height, other.width * other.height);
            const titleDistance = Math.max(Math.abs(point.x - other.x), Math.abs(point.y - other.y));
            score += Math.max(0, covered - 0.96) + Math.max(0, 24 - titleDistance) / 24;
        }
        if (score < bestScore) { best = point; bestScore = score; }
        if (score === 0) return point;
    }
    return best;
}
