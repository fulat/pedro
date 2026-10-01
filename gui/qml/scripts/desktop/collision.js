.pragma library

// Sweep every selected rectangle together, then slide along the first barrier.
function constrain(items, obstacles, movementX, movementY) {
    let offsetX = 0;
    let offsetY = 0;
    for (let pass = 0; pass < 4 && (movementX !== 0 || movementY !== 0); ++pass) {
        let time = 1;
        let blockX = false;
        let blockY = false;
        for (const item of items) {
            const x = item.x + offsetX;
            const y = item.y + offsetY;
            for (const obstacle of obstacles) {
                const left = obstacle.x - item.width;
                const right = obstacle.x + obstacle.width;
                const top = obstacle.y - item.height;
                const bottom = obstacle.y + obstacle.height;
                if ((movementX === 0 && (x <= left || x >= right))
                        || (movementY === 0 && (y <= top || y >= bottom))) {
                    continue;
                }
                const enterX = movementX === 0 ? -Infinity : ((movementX > 0 ? left : right) - x) / movementX;
                const exitX = movementX === 0 ? Infinity : ((movementX > 0 ? right : left) - x) / movementX;
                const enterY = movementY === 0 ? -Infinity : ((movementY > 0 ? top : bottom) - y) / movementY;
                const exitY = movementY === 0 ? Infinity : ((movementY > 0 ? bottom : top) - y) / movementY;
                const enter = Math.max(enterX, enterY);
                const exit = Math.min(exitX, exitY);
                if (enter < -0.000001 || enter > time || exit <= Math.max(0, enter)) {
                    continue;
                }
                const sameTime = Math.abs(enter - time) < 0.000001;
                const hitX = enterX >= enterY;
                const hitY = enterY >= enterX;
                blockX = sameTime ? blockX || hitX : hitX;
                blockY = sameTime ? blockY || hitY : hitY;
                time = Math.max(0, enter);
            }
        }
        const travel = Math.max(0, time - ((blockX || blockY)
            ? 0.0000001 / Math.max(1, Math.abs(movementX), Math.abs(movementY)) : 0));
        offsetX += movementX * travel;
        offsetY += movementY * travel;
        movementX = blockX ? 0 : movementX * (1 - time);
        movementY = blockY ? 0 : movementY * (1 - time);
    }
    return {x: offsetX, y: offsetY};
}
