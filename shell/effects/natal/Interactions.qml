import QtQuick
import "common/Colors.js" as Colors

// Natal's effects on Speshell's controls. A dragged bauble now and then glints or
// shakes off a little snow, and glints where it is let go. Picking something grows a
// snowflake at the pointer, which glints and breaks into tiny flakes that drift down.
// A switch turned on blooms warm round its bulbs; turned off, a few flakes puff off it.
Item {
    id: root

    // ── Speshell effects API v1: interactions ───────────────
    property var theme: Colors.fallback

    // Travel since the last glint or snow, and how far the next one waits.
    property real moved: 0
    property real due: 70
    property bool snowNext: false

    // A tiny flake at (x, y), drifting off with velocity (vx, vy).
    function mote(x, y, vx, vy, delay, life) {
        bits.emit(bits.mote, { x: x, y: y, vx: vx, vy: vy, gravity: 70, drag: 2.2, life: life, delay: delay,
            size: Math.round(bits.rnd(6, 9)), angle: bits.rnd(0, 60), spin: bits.rnd(-120, 120) });
    }

    function slide(at, dx) {
        root.moved += Math.abs(dx);
        if (root.moved < root.due)
            return;
        root.moved = 0;
        root.due = bits.rnd(55, 100);
        const away = dx > 0 ? -1 : 1;
        if (root.snowNext) {
            for (let i = 0; i < 2; i++)
                root.mote(at.x + away * bits.rnd(3, 7), at.y - bits.rnd(4, 8), away * bits.rnd(15, 45), -bits.rnd(25, 50), i * 0.06, 0.55);
        } else {
            bits.emit(bits.glint, { x: at.x - bits.rnd(2, 4), y: at.y - bits.rnd(3, 5), life: 0.35, size: Math.round(bits.rnd(8, 11)) });
        }
        root.snowNext = !root.snowNext;
    }

    function release(at) {
        bits.emit(bits.glint, { x: at.x - 3, y: at.y - 4, life: 0.4, size: 11 });
    }

    // The flake is turned at random; the tiny flakes it breaks into leave from its
    // arms, every other one from a random first.
    function pick(area, at) {
        const turn = bits.rnd(0, Math.PI / 3);
        bits.emit(bits.flake, { x: at.x, y: at.y, life: 0.8, size: 56, props: { turn: turn } });
        const first = Math.floor(bits.rnd(0, 6));
        const n = 3 + Math.floor(bits.rnd(0, 2));
        for (let i = 0; i < n; i++) {
            const a = turn + (first + i * (n === 3 ? 2 : 1.5)) * Math.PI / 3;
            const r = bits.rnd(8, 14);
            root.mote(at.x + Math.cos(a) * r, at.y + Math.sin(a) * r, Math.cos(a) * bits.rnd(8, 20), Math.sin(a) * 8 + bits.rnd(0, 10),
                0.4 + bits.rnd(0, 0.06), bits.rnd(0.42, 0.55));
        }
    }

    function toggle(area, on) {
        if (on) {
            bits.emit(bits.bloom, { x: area.x + area.width * 0.36, y: area.y + area.height * 0.5, life: 0.5, delay: 0.08, size: Math.round(area.width * 0.95) });
            return;
        }
        for (let i = 0; i < 3; i++)
            root.mote(area.x + area.width * bits.rnd(0.5, 0.85), area.y + area.height * bits.rnd(0.2, 0.4), bits.rnd(-15, 15), -bits.rnd(30, 50), i * 0.05, 0.6);
    }

    Bits {
        id: bits
        anchors.fill: parent
        theme: root.theme
    }
}
