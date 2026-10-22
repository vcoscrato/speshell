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
    property var theme: null

    // Travel not yet paid out in chips and dust, px.
    property real chipOwed: 0
    property real dustOwed: 0

    function rnd(a, b) {
        return a + Math.random() * (b - a);
    }

    function chip(x, y, vx, vy, floor) {
        bits.spawn({ x: x, y: y, vx: vx, vy: vy, floor: floor, life: rnd(0.55, 0.85),
                     size: Math.round(rnd(8, 12)), angle: rnd(0, 360), spin: rnd(-600, 600),
                     props: { kind: 0, seed: Math.random(), z: 1 } });
    }

    // A big stone, thrown high and slow-turning, that lands with a bounce.
    function pebble(x, y, vx, vy, floor) {
        bits.spawn({ x: x, y: y, vx: vx, vy: vy, floor: floor, bounce: 0.45, life: rnd(0.8, 0.95),
                     size: Math.round(rnd(13, 16)), angle: rnd(0, 360), spin: rnd(-320, 320),
                     props: { kind: 0, seed: Math.random(), z: 2 } });
    }

    function grit(x, y, vx, vy, floor) {
        bits.spawn({ x: x, y: y, vx: vx, vy: vy, floor: floor, drag: 0.8, life: rnd(0.4, 0.65),
                     size: Math.round(rnd(5, 7)), props: { kind: 2, seed: Math.random(), z: 1 } });
    }

    function puff(x, y, vx, size) {
        bits.spawn({ x: x, y: y, vx: vx, vy: -rnd(10, 30), drag: 5, gravity: -20, life: rnd(0.4, 0.6),
                     size: size, props: { kind: 1, seed: Math.random(), z: 0 } });
    }

    function slide(at, dx) {
        var back = dx > 0 ? -1 : 1;
        root.chipOwed = Math.min(root.chipOwed + Math.abs(dx), 40);
        while (root.chipOwed >= 9) {
            root.chipOwed -= 9;
            root.chip(at.x + back * rnd(2, 7), at.y + rnd(0, 3), back * rnd(50, 170), -rnd(140, 300), at.y + 9);
        }
        root.dustOwed += Math.abs(dx);
        if (root.dustOwed >= 24) {
            root.dustOwed = 0;
            root.puff(at.x + back * 6, at.y + 5, back * rnd(20, 50), 18);
        }
    }

    function release(at) {
        root.puff(at.x - 7, at.y + 5, -35, 16);
        root.puff(at.x + 7, at.y + 5, 35, 16);
        root.chip(at.x, at.y, rnd(-50, 50), -rnd(90, 140), at.y + 9);
        root.grit(at.x - 3, at.y, -rnd(30, 80), -rnd(80, 140), at.y + 9);
        root.grit(at.x + 3, at.y, rnd(30, 80), -rnd(80, 140), at.y + 9);
    }

    function pick(area, at) {
        var cx = at.x, cy = at.y;
        var floor = area.y + area.height + 6;
        var side = Math.random() < 0.5 ? -1 : 1;
        root.puff(cx, cy, 0, 26);
        root.pebble(cx + side * 3, cy, side * rnd(30, 90), -rnd(300, 360), floor);
        root.pebble(cx - side * 3, cy, -side * rnd(60, 130), -rnd(220, 280), floor);
        for (var i = 0; i < 5; i++) {
            var s = i % 2 ? side : -side;
            root.chip(cx + rnd(-6, 6), cy, s * rnd(70, 200), -rnd(160, 320), floor);
        }
        for (var j = 0; j < 8; j++)
            root.grit(cx + rnd(-5, 5), cy, rnd(-240, 240), -rnd(120, 380), floor);
        root.puff(cx - 14, floor - 6, -35, 18);
        root.puff(cx + 14, floor - 6, 35, 18);
    }

    function toggle(area, on) {
        var x = on ? area.x + area.width - area.height / 2 : area.x + area.height / 2;
        var cy = area.y + area.height / 2, floor = area.y + area.height + 6;
        if (on) {
            root.pebble(x, cy, rnd(20, 90), -rnd(260, 320), floor);
            for (var i = 0; i < 3; i++)
                root.chip(x, cy, rnd(-40, 160), -rnd(180, 300), floor);
            for (var j = 0; j < 5; j++)
                root.grit(x, cy, rnd(-80, 200), -rnd(120, 320), floor);
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
                property color cStone: root.theme ? Colors.mix(root.theme.overlay, root.theme.subtext, 0.4) : "#7f8669"
                property color cLight: root.theme ? root.theme.subtextBright : "#c6c6ad"
                property color cShade: root.theme ? root.theme.crust : "#0d0f0a"
                property color cDust: root.theme ? root.theme.peach : "#d99a5a"
                fragmentShader: Qt.resolvedUrl("qsb/Interactions.qsb")
            }
        }
    }
}
