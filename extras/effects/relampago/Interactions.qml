import QtQuick

// Relâmpago's effects on Speshell's controls. A knob dragged along a slider
// throws sparks off behind it with arcs of electricity crackling into it; let go,
// it discharges in a burst. Picking something calls lightning down onto it. A
// switch turned on is struck too; turned off, it smokes.
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
        while (root.sparkOwed >= 9) {
            root.sparkOwed -= 9;
            bits.emit(bits.spark, { x: at.x - fwd * bits.rnd(4, 9), y: at.y + bits.rnd(-3, 5),
                                    vx: -fwd * bits.rnd(80, 220), vy: -bits.rnd(60, 200), gravity: 700,
                                    life: bits.rnd(0.25, 0.45), size: Math.round(bits.rnd(14, 22)), orient: true });
        }
        // Arcs reaching into the knob from the track behind it.
        root.arcOwed += d;
        if (root.arcOwed >= 14) {
            root.arcOwed = 0;
            var size = Math.round(bits.rnd(34, 56));
            bits.emit(bits.arc, { x: at.x - fwd * size * 0.45, y: at.y + bits.rnd(-2, 2), vx: fwd * 30, vy: bits.rnd(-4, 4),
                                  drag: 3, life: bits.rnd(0.22, 0.32), size: size, orient: true });
        }
    }

    function release(at) {
        bits.emit(bits.burst, { x: at.x, y: at.y, life: 0.4, size: 44 });
        for (var i = 0; i < 3; i++)
            bits.emit(bits.spark, { x: at.x, y: at.y, vx: bits.rnd(-150, 150), vy: -bits.rnd(60, 180), gravity: 600,
                                    life: bits.rnd(0.25, 0.4), size: 16, orient: true });
    }

    function pick(area, at) {
        var cx = at.x, cy = at.y;
        var size = Math.max(80, Math.min(150, Math.max(area.width, area.height) * 3));
        bits.emit(bits.strike, { x: cx, y: cy, life: 0.45, size: Math.round(size), angle: bits.rnd(-20, 20) });
        for (var i = 0; i < 4; i++) {
            var a = bits.rnd(0, 2 * Math.PI);
            bits.emit(bits.spark, { x: cx, y: cy, vx: Math.cos(a) * bits.rnd(80, 180), vy: Math.sin(a) * bits.rnd(80, 180) - 40,
                                    gravity: 400, life: bits.rnd(0.25, 0.4), size: 16, orient: true, delay: 0.05 });
        }
    }

    function toggle(area, on) {
        var x = on ? area.x + area.width - area.height / 2 : area.x + area.height / 2;
        var cy = area.y + area.height / 2;
        if (on) {
            bits.emit(bits.strike, { x: x, y: cy, life: 0.45, size: 80, angle: bits.rnd(-15, 15) });
            for (var i = 0; i < 3; i++)
                bits.emit(bits.spark, { x: x, y: cy, vx: bits.rnd(-140, 140), vy: -bits.rnd(60, 160), gravity: 600,
                                        life: bits.rnd(0.25, 0.4), size: 14, orient: true, delay: 0.05 });
        } else {
            bits.emit(bits.smoke, { x: x, y: cy - 4, vx: bits.rnd(-15, 15), vy: -bits.rnd(25, 45), drag: 2, life: 0.7, size: 28 });
        }
    }

    Bits {
        id: bits
        anchors.fill: parent
        theme: root.theme
    }
}
