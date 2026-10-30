import QtQuick

// Relâmpago's effects on Speshell's controls, drawn like cartoons. A knob dragged
// along a slider throws fat sparks off behind it with zigzag arcs crackling into it;
// let go, it pops in a little starburst. Picking something calls a bolt down onto it,
// with a glint. A switch turned on is struck too; turned off, it puffs smoke.
Item {
    id: root

    // ── Speshell effects API v1: interactions ───────────────
    property var theme: null

    // Travel not yet paid out in sparks and arcs, px.
    property real sparkOwed: 0
    property real arcOwed: 0

    function slide(at, dx) {
        var fwd = dx > 0 ? 1 : -1;
        var d = Math.abs(dx);
        root.sparkOwed = Math.min(root.sparkOwed + d, 40);
        while (root.sparkOwed >= 11) {
            root.sparkOwed -= 11;
            bits.emit(bits.spark, { x: at.x - fwd * bits.rnd(4, 9), y: at.y + bits.rnd(-2, 5),
                                    vx: -fwd * bits.rnd(90, 240), vy: -bits.rnd(80, 220), gravity: 800,
                                    life: bits.rnd(0.28, 0.45), size: Math.round(bits.rnd(18, 26)), orient: true });
        }
        // Arcs reaching into the knob from the track behind it.
        root.arcOwed += d;
        if (root.arcOwed >= 18) {
            root.arcOwed = 0;
            var size = Math.round(bits.rnd(26, 40));
            bits.emit(bits.arc, { x: at.x - fwd * size * 0.45, y: at.y + bits.rnd(-2, 2), vx: fwd * 30, vy: bits.rnd(-4, 4),
                                  drag: 3, life: bits.rnd(0.22, 0.32), size: size, orient: true });
        }
    }

    function release(at) {
        bits.emit(bits.star, { x: at.x, y: at.y, life: 0.38, size: 46, angle: bits.rnd(0, 360) });
        for (var i = 0; i < 3; i++)
            bits.emit(bits.spark, { x: at.x, y: at.y, vx: bits.rnd(-170, 170), vy: -bits.rnd(80, 200), gravity: 700,
                                    life: bits.rnd(0.28, 0.42), size: 20, orient: true, delay: 0.03 });
        bits.emit(bits.glint, { x: at.x + bits.rnd(8, 14), y: at.y - bits.rnd(8, 14), life: 0.35, size: 16, delay: 0.08 });
    }

    function pick(area, at) {
        var cx = at.x, cy = at.y;
        var size = Math.max(70, Math.min(100, Math.max(area.width, area.height) * 3));
        bits.emit(bits.strike, { x: cx, y: cy, life: 0.45, size: Math.round(size), angle: bits.rnd(-20, 20) });
        // Sparks fly up and out of the line picked, not along it.
        for (var i = 0; i < 4; i++) {
            var a = -Math.PI / 2 + bits.rnd(-1.0, 1.0);
            bits.emit(bits.spark, { x: cx, y: cy, vx: Math.cos(a) * bits.rnd(90, 190), vy: Math.sin(a) * bits.rnd(120, 220),
                                    gravity: 500, life: bits.rnd(0.28, 0.42), size: 20, orient: true, delay: 0.05 });
        }
        bits.emit(bits.glint, { x: area.x + area.width - 2, y: area.y + 2, life: 0.4, size: 18, delay: 0.12 });
    }

    function toggle(area, on) {
        var x = on ? area.x + area.width - area.height / 2 : area.x + area.height / 2;
        var cy = area.y + area.height / 2;
        if (on) {
            bits.emit(bits.strike, { x: x, y: cy, life: 0.45, size: 80, angle: bits.rnd(-15, 15) });
            for (var i = 0; i < 3; i++)
                bits.emit(bits.spark, { x: x, y: cy, vx: bits.rnd(-150, 150), vy: -bits.rnd(80, 180), gravity: 700,
                                        life: bits.rnd(0.28, 0.4), size: 18, orient: true, delay: 0.05 });
        } else {
            bits.emit(bits.smoke, { x: x, y: cy - 4, vx: bits.rnd(-15, 15), vy: -bits.rnd(25, 45), drag: 2, life: 0.7, size: 30 });
            bits.emit(bits.smoke, { x: x + bits.rnd(-6, 6), y: cy - 2, vx: bits.rnd(-25, 25), vy: -bits.rnd(15, 30), drag: 2,
                                    life: 0.55, size: 20, delay: 0.08 });
        }
    }

    Bits {
        id: bits
        anchors.fill: parent
        theme: root.theme
    }
}
