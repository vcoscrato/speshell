import QtQuick
import "common"

// Air's effects on Speshell's controls. A knob dragged along a slider is blown
// along by wind from behind: streaks overtake it, parting around it, now and then
// carrying a leaf; let go, it curls into a little eddy. Picking something swirls a
// curl of wind around it with a leaf caught up. A switch turned on gusts; turned off,
// it lets a little dust settle.
Item {
    id: root

    // ── Speshell effects API v1: interactions ───────────────
    property var theme: null

    // Travel not yet paid out in streaks and leaves, px.
    property real streakOwed: 0
    property real leafOwed: 0
    property real leafEvery: 40

    function rnd(a, b) {
        return a + Math.random() * (b - a);
    }

    function wisp(x, y, vx, vy, size) {
        bits.spawn({ x: x, y: y, vx: vx, vy: vy, drag: 2.5, life: rnd(0.4, 0.6), size: size, orient: true,
                     props: { kind: 0, seed: Math.random(), z: 0 } });
    }

    function leaf(x, y, vx, vy) {
        bits.spawn({ x: x, y: y, vx: vx, vy: vy, gravity: 160, drag: 1.5, life: rnd(0.8, 1.0),
                     size: Math.round(rnd(12, 16)), angle: rnd(0, 360), spin: rnd(-420, 420),
                     props: { kind: 1, seed: Math.random(), z: 2 } });
    }

    function curl(x, y, size) {
        bits.spawn({ x: x, y: y, life: 0.55, size: size, props: { kind: 2, seed: Math.random(), z: 1 } });
    }

    function speck(x, y) {
        bits.spawn({ x: x, y: y, vx: rnd(-25, 25), vy: rnd(10, 40), drag: 1, life: rnd(0.5, 0.8), size: 4,
                     props: { kind: 3, seed: Math.random(), z: 1 } });
    }

    function streak(x, y, vx, vy, size) {
        bits.spawn({ x: x, y: y, vx: vx, vy: vy, drag: 1.2, life: rnd(0.35, 0.5), size: Math.round(size), orient: true,
                     props: { kind: 4, seed: Math.random(), z: 0 } });
    }

    // Wind from behind the knob blows it along: streaks overtake it, parting above and
    // below, and now and then carry a leaf past.
    function slide(at, dx) {
        var dir = dx > 0 ? 1 : -1;
        root.streakOwed = Math.min(root.streakOwed + Math.abs(dx), 40);
        while (root.streakOwed >= 10) {
            root.streakOwed -= 10;
            var off = (Math.random() < 0.5 ? -1 : 1) * rnd(4, 15);
            root.streak(at.x - dir * rnd(30, 80), at.y + off, dir * rnd(420, 600), off * rnd(1.5, 3), rnd(48, 80));
        }
        root.leafOwed += Math.abs(dx);
        if (root.leafOwed >= root.leafEvery) {
            root.leafOwed = 0;
            root.leafEvery = rnd(50, 90);
            root.leaf(at.x - dir * rnd(20, 40), at.y - rnd(4, 12), dir * rnd(260, 380), -rnd(60, 140));
        }
    }

    function release(at) {
        root.curl(at.x, at.y, 46);
        root.speck(at.x - 4, at.y - 6);
        root.speck(at.x + 5, at.y - 3);
    }

    function pick(area, at) {
        var cx = at.x, cy = at.y;
        var size = Math.max(44, Math.min(96, Math.max(area.width, area.height) * 2));
        root.curl(cx, cy, size);
        root.leaf(cx + size * 0.3, cy - size * 0.2, rnd(40, 100), -rnd(80, 140));
        root.wisp(cx - size * 0.4, cy + size * 0.15, 30, -60, 34);
        root.wisp(cx + size * 0.4, cy - size * 0.15, -30, 60, 34);
    }

    function toggle(area, on) {
        var x = on ? area.x + area.width - area.height / 2 : area.x + area.height / 2;
        var cy = area.y + area.height / 2;
        if (on) {
            root.curl(x, cy, 36);
            root.leaf(x, cy - 6, rnd(40, 110), -rnd(90, 150));
        } else {
            for (var i = 0; i < 3; i++)
                root.speck(x + rnd(-6, 6), cy - rnd(0, 8));
        }
    }

    Particles {
        id: bits
        anchors.fill: parent
        delegate: Component {
            ShaderEffect {
                property real age: 0
                property real seed: 0
                property real kind: 0
                property real size: width
                property color cWind: root.theme ? root.theme.text : "#f4ead8"
                property color cLeaf: root.theme ? root.theme.accent : "#f39a3a"
                property color cLeafBack: root.theme ? root.theme.peach : "#f0a03c"
                property color cOutline: root.theme ? root.theme.crust : "#130f0b"
                fragmentShader: Qt.resolvedUrl("qsb/Interactions.qsb")
            }
        }
    }
}
