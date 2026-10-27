import QtQuick

// Sugar's effects on Speshell's controls, kept small and light, since the knob's bag
// and spatula do the work on a slider. A glint now and then on frosting freshly piped,
// and one where it is let go. Picking something sifts a little powdered sugar down
// over where you clicked; a switch turned on gets a sifting too, and turned off, a few
// grains of sugar fall from it.
Item {
    id: root

    // ── Speshell effects API v1: interactions ───────────────
    property var theme: null

    // Travel piped since the last glint, px.
    property real piped: 0

    function slide(at, dx) {
        if (dx < 0)
            return;
        root.piped += dx;
        if (root.piped >= 70) {
            root.piped = 0;
            bits.emit(bits.sparkle, { x: at.x - bits.rnd(10, 30), y: at.y - bits.rnd(2, 5), life: 0.35, size: Math.round(bits.rnd(7, 10)) });
        }
    }

    function release(at) {
        bits.emit(bits.sparkle, { x: at.x + bits.rnd(-3, 3), y: at.y - bits.rnd(9, 12), life: 0.4, size: 10 });
    }

    function pick(area, at) {
        bits.emit(bits.sift, { x: at.x, y: at.y + 4, life: 0.95, size: 48 });
    }

    function toggle(area, on) {
        var x = on ? area.x + area.width - area.height / 2 : area.x + area.height / 2;
        var cy = area.y + area.height / 2;
        if (on) {
            bits.emit(bits.sift, { x: x, y: cy + 2, life: 0.9, size: 36 });
        } else {
            for (var i = 0; i < 4; i++)
                bits.emit(bits.grain, { x: x + bits.rnd(-5, 5), y: cy + bits.rnd(-2, 3), vx: bits.rnd(-20, 20), vy: bits.rnd(-30, 10),
                                        gravity: 300, life: bits.rnd(0.4, 0.6), size: Math.round(bits.rnd(4, 6)), delay: i * 0.03 });
        }
    }

    Bits {
        id: bits
        anchors.fill: parent
        theme: root.theme
    }
}
