import QtQuick
import "common"
import "common/Colors.js" as Colors

// Earth's effects on Speshell's controls. A knob dragged along a slider kicks up
// chips of rock and dust behind it, which arc, bounce on the track, and tumble away;
// let go, it settles in dust. Picking something knocks stones loose from it: a couple
// of pebbles thrown high, chips flung wider, and a spray of grit, all bouncing where
// they land, over a burst of dust. A switch turned on throws stones off its thumb;
// turned off, it settles in dust.
Item {
    id: root

    // ── Speshell effects API v1: interactions ───────────────
    property var theme: Colors.fallback

    // Travel not yet paid out in chips and dust, px.
    property real chipOwed: 0
    property real dustOwed: 0

    function chip(x, y, vx, vy, floor) {
        bits.emit(0, { x: x, y: y, vx: vx, vy: vy, floor: floor, life: bits.rnd(0.55, 0.85),
                       size: Math.round(bits.rnd(8, 12)), angle: bits.rnd(0, 360), spin: bits.rnd(-600, 600),
                       props: { z: 1 } });
    }

    // A big stone, thrown high and slow-turning, that lands with a bounce.
    function pebble(x, y, vx, vy, floor) {
        bits.emit(0, { x: x, y: y, vx: vx, vy: vy, floor: floor, bounce: 0.45, life: bits.rnd(0.8, 0.95),
                       size: Math.round(bits.rnd(13, 16)), angle: bits.rnd(0, 360), spin: bits.rnd(-320, 320),
                       props: { z: 2 } });
    }

    function grit(x, y, vx, vy, floor) {
        bits.emit(2, { x: x, y: y, vx: vx, vy: vy, floor: floor, drag: 0.8, life: bits.rnd(0.4, 0.65),
                       size: Math.round(bits.rnd(5, 7)), props: { z: 1 } });
    }

    function puff(x, y, vx, size) {
        bits.emit(1, { x: x, y: y, vx: vx, vy: -bits.rnd(10, 30), drag: 5, gravity: -20, life: bits.rnd(0.4, 0.6),
                       size: size, props: { z: 0 } });
    }

    function slide(at, dx) {
        const back = dx > 0 ? -1 : 1;
        root.chipOwed = Math.min(root.chipOwed + Math.abs(dx), 40);
        while (root.chipOwed >= 9) {
            root.chipOwed -= 9;
            root.chip(at.x + back * bits.rnd(2, 7), at.y + bits.rnd(0, 3), back * bits.rnd(50, 170), -bits.rnd(140, 300), at.y + 9);
        }
        root.dustOwed += Math.abs(dx);
        if (root.dustOwed >= 24) {
            root.dustOwed = 0;
            root.puff(at.x + back * 6, at.y + 5, back * bits.rnd(20, 50), 18);
        }
    }

    function release(at) {
        root.puff(at.x - 7, at.y + 5, -35, 16);
        root.puff(at.x + 7, at.y + 5, 35, 16);
        root.chip(at.x, at.y, bits.rnd(-50, 50), -bits.rnd(90, 140), at.y + 9);
        root.grit(at.x - 3, at.y, -bits.rnd(30, 80), -bits.rnd(80, 140), at.y + 9);
        root.grit(at.x + 3, at.y, bits.rnd(30, 80), -bits.rnd(80, 140), at.y + 9);
    }

    function pick(area, at) {
        const cx = at.x, cy = at.y;
        const floor = area.y + area.height + 6;
        const side = Math.random() < 0.5 ? -1 : 1;
        root.puff(cx, cy, 0, 26);
        root.pebble(cx + side * 3, cy, side * bits.rnd(30, 90), -bits.rnd(300, 360), floor);
        root.pebble(cx - side * 3, cy, -side * bits.rnd(60, 130), -bits.rnd(220, 280), floor);
        for (let i = 0; i < 5; i++) {
            const s = i % 2 ? side : -side;
            root.chip(cx + bits.rnd(-6, 6), cy, s * bits.rnd(70, 200), -bits.rnd(160, 320), floor);
        }
        for (let j = 0; j < 8; j++)
            root.grit(cx + bits.rnd(-5, 5), cy, bits.rnd(-240, 240), -bits.rnd(120, 380), floor);
        root.puff(cx - 14, floor - 6, -35, 18);
        root.puff(cx + 14, floor - 6, 35, 18);
    }

    function toggle(area, on) {
        const x = on ? area.x + area.width - area.height / 2 : area.x + area.height / 2;
        const cy = area.y + area.height / 2, floor = area.y + area.height + 6;
        if (on) {
            root.pebble(x, cy, bits.rnd(20, 90), -bits.rnd(260, 320), floor);
            for (let i = 0; i < 3; i++)
                root.chip(x, cy, bits.rnd(-40, 160), -bits.rnd(180, 300), floor);
            for (let j = 0; j < 5; j++)
                root.grit(x, cy, bits.rnd(-80, 200), -bits.rnd(120, 320), floor);
        } else {
            root.puff(x - 5, floor - 6, -30, 18);
            root.puff(x + 5, floor - 6, 30, 18);
        }
    }

    Particles {
        id: bits
        anchors.fill: parent
        gravity: 900
        delegate: Component {
            ShaderEffect {
                property real age: 0
                property real seed: 0
                property real kind: 0
                property real size: width
                property color cStone: Colors.mix(root.theme.overlay, root.theme.subtext, 0.4)
                property color cLight: root.theme.subtextBright
                property color cShade: root.theme.crust
                property color cDust: root.theme.peach
                fragmentShader: Qt.resolvedUrl("qsb/Interactions.qsb")
            }
        }
    }
}
