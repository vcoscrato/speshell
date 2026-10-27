import QtQuick

// Sugar's effects on Speshell's controls, kept small and light, since the knob's bag
// and spatula do the work on a slider. A glint now and then on frosting freshly piped,
// and one where it is let go. Picking something sifts a little powdered sugar down
// over where you clicked; a switch turned on glints on its fresh fondant.
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

    // A switch turned on glints along its fresh fondant.
    function toggle(area, on) {
        if (!on)
            return;
        var cy = area.y + area.height * 0.35;
        for (var i = 0; i < 2; i++)
            bits.emit(bits.sparkle, { x: area.x + area.width * (0.22 + i * 0.25), y: cy + i * 2, life: 0.4, size: 8 + i, delay: 0.12 + i * 0.1 });
    }

    Bits {
        id: bits
        anchors.fill: parent
        theme: root.theme
    }
}
