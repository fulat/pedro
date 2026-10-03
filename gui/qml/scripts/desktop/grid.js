.pragma library

function intersects(first, second, gap) {
    return first.x < second.x + second.width + gap
        && first.x + first.width + gap > second.x
        && first.y < second.y + second.height + gap
        && first.y + first.height + gap > second.y;
}

// Maximal free rectangles retain screen edges wherever chrome does not block them.
function regions(bounds, obstacles, itemWidth, itemHeight) {
    const right = bounds.x + bounds.width;
    const bottom = bounds.y + bounds.height;
    const edges = [bounds.x, right];
    const barriers = obstacles.filter(obstacle => intersects(bounds, obstacle, 0));

    for (const obstacle of barriers) {
        edges.push(Math.max(bounds.x, obstacle.x));
        edges.push(Math.min(right, obstacle.x + obstacle.width));
    }

    edges.sort((first, second) => first - second);
    const uniqueEdges = edges.filter((value, index) => index === 0 || value !== edges[index - 1]);
    const result = [];

    for (let leftIndex = 0; leftIndex < uniqueEdges.length - 1; ++leftIndex) {
        const left = uniqueEdges[leftIndex];

        for (let rightIndex = leftIndex + 1; rightIndex < uniqueEdges.length; ++rightIndex) {
            const edge = uniqueEdges[rightIndex];
            if (edge - left < itemWidth) {
                continue;
            }

            const intervals = barriers.filter(obstacle => obstacle.x < edge && obstacle.x + obstacle.width > left)
                .map(obstacle => ({top: Math.max(bounds.y, obstacle.y), bottom: Math.min(bottom, obstacle.y + obstacle.height)}))
                .sort((first, second) => first.top - second.top);
            let top = bounds.y;

            for (const interval of intervals.concat([{top: bottom, bottom: bottom}])) {
                if (interval.top - top >= itemHeight) {
                    result.push({x: left, y: top, width: edge - left, height: interval.top - top});
                }
                top = Math.max(top, interval.bottom);
            }
        }
    }

    return result.filter((region, index) => !result.some((other, otherIndex) => otherIndex !== index
        && other.x <= region.x && other.y <= region.y
        && other.x + other.width >= region.x + region.width
        && other.y + other.height >= region.y + region.height));
}

// Each free region starts its grid at its own boundary, including obstacle edges.
function candidates(bounds, obstacles, itemWidth, itemHeight, cellWidth, cellHeight) {
    const result = [];

    for (const region of regions(bounds, obstacles, itemWidth, itemHeight)) {
        const columns = Math.floor((region.width - itemWidth) / cellWidth);
        const rows = Math.floor((region.height - itemHeight) / cellHeight);
        const stepX = columns > 0 ? (region.width - itemWidth) / columns : cellWidth;
        const stepY = rows > 0 ? (region.height - itemHeight) / rows : cellHeight;

        for (let row = 0; row <= rows; ++row) {
            for (let column = 0; column <= columns; ++column) {
                result.push({x: region.x + column * stepX, y: region.y + row * stepY,
                    cellWidth: stepX, cellHeight: stepY});
            }
        }
    }

    return result;
}

// Translate all selected cells together, preserving their relative grid offsets.
function placement(bounds, obstacles, occupied, items, target, cellWidth, cellHeight, gap) {
    let best = null;
    let bestDistance = Infinity;

    for (const candidate of candidates(bounds, obstacles, items[0].width, items[0].height, cellWidth, cellHeight)) {
        const proposed = items.map(item => ({x: candidate.x + item.column * candidate.cellWidth,
            y: candidate.y + item.row * candidate.cellHeight, width: item.width, height: item.height}));
        const valid = proposed.every((item, index) => item.x >= bounds.x - 0.000001
            && item.y >= bounds.y - 0.000001
            && item.x + item.width <= bounds.x + bounds.width + 0.000001
            && item.y + item.height <= bounds.y + bounds.height + 0.000001
            && !obstacles.some(obstacle => intersects(item, obstacle, -0.000001))
            && !occupied.some(other => intersects(item, other, gap - 0.000001))
            && !proposed.some((other, otherIndex) => index !== otherIndex && intersects(item, other, gap - 0.000001)));
        const distance = Math.pow(candidate.x - target.x, 2) + Math.pow(candidate.y - target.y, 2);

        if (valid && distance < bestDistance) {
            best = proposed;
            bestDistance = distance;
        }
    }

    return best;
}
