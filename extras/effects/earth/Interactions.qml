import QtQuick
import "common"

// Earth's effects on Speshell's controls. A knob dragged along a slider kicks up
// chips of rock and dust behind it, which arc, bounce on the track, and tumble away;
// let go, it settles in dust. Picking something knocks pebbles and a jade shard loose
// from it. A switch turned on throws chips; turned off, it settles in dust.
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
                     size: Math.round(rnd(7, 12)), angle: rnd(0, 360), spin: rnd(-600, 600),
                     props: { kind: 0, seed: Math.random(), z: 1 } });
    }

    function puff(x, y, vx, size) {
        bits.spawn({ x: x, y: y, vx: vx, vy: -rnd(10, 30), drag: 5, gravity: -20, life: rnd(0.4, 0.6),
                     size: size, props: { kind: 1, seed: Math.random(), z: 0 } });
    }

    function shard(x, y) {
        bits.spawn({ x: x, y: y, vx: rnd(-60, 60), vy: -rnd(200, 280), life: 0.6, size: 11,
                     angle: rnd(-30, 30), spin: rnd(-300, 300), props: { kind: 2, seed: Math.random(), z: 2 } });
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
    }

    function pick(area, at) {
        var cx = at.x, cy = at.y;
        var floor = area.y + area.height + 6;
        for (var i = 0; i < 5; i++)
            root.chip(cx + rnd(-area.width, area.width) * 0.3, cy, rnd(-130, 130), -rnd(170, 320), floor);
        root.shard(cx, cy);
        root.puff(area.x + 4, floor - 4, -30, 20);
        root.puff(area.x + area.width - 4, floor - 4, 30, 20);
    }

    function toggle(area, on) {
        var x = on ? area.x + area.width - area.height / 2 : area.x + area.height / 2;
        var cy = area.y + area.height / 2, floor = area.y + area.height + 6;
        if (on) {
            for (var i = 0; i < 4; i++)
                root.chip(x, cy, rnd(-40, 160), -rnd(180, 300), floor);
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
                property color cStone: root.theme ? root.theme.overlay : "#677052"
                property color cLight: root.theme ? root.theme.subtextBright : "#c6c6ad"
                property color cShade: root.theme ? root.theme.crust : "#0d0f0a"
                property color cDust: root.theme ? root.theme.peach : "#d99a5a"
                property color cJade: root.theme ? root.theme.accent : "#5fa57a"
                property color cGlint: root.theme ? root.theme.text : "#e9e6d3"
                fragmentShader: Qt.resolvedUrl("qsb/Interactions.qsb")
            }
        }
    }
}
