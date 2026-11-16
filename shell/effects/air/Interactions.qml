import QtQuick
import "common/Colors.js" as Colors
import "common"

// Air's effects on Speshell's controls. A knob dragged along a slider is blown
// along by a gust from behind, a plume of breath that opens to it and grows as the
// drag goes on, carrying a speck or a leaf; let go, it dies away and the knob curls
// into a little eddy. Picking something swirls a curl of wind around it with a leaf
// caught up. A switch turned on gusts; turned off, it lets a little dust settle.
Item {
    id: root

    // ── Speshell effects API v1: interactions ───────────────
    property var theme: Colors.fallback

    // Travel not yet paid out in specks and leaves, px, and time since the last of each, s.
    property real speckOwed: 0
    property real leafOwed: 0
    property real leafEvery: 120
    property real sinceSpeck: 1
    property real sinceLeaf: 1

    function wisp(x, y, vx, vy, size) {
        bits.emit(0, { x: x, y: y, vx: vx, vy: vy, drag: 2.5, life: bits.rnd(0.4, 0.6), size: size, orient: true,
                       props: { z: 0 } });
    }

    function leaf(x, y, vx, vy) {
        bits.emit(1, { x: x, y: y, vx: vx, vy: vy, gravity: 160, drag: 1.5, life: bits.rnd(0.8, 1.0),
                       size: Math.round(bits.rnd(12, 16)), angle: bits.rnd(0, 360), spin: bits.rnd(-420, 420),
                       props: { z: 2 } });
    }

    function curl(x, y, size) {
        bits.emit(2, { x: x, y: y, life: 0.55, size: size, props: { z: 1 } });
    }

    function speck(x, y) {
        bits.emit(3, { x: x, y: y, vx: bits.rnd(-25, 25), vy: bits.rnd(10, 40), drag: 1, life: bits.rnd(0.5, 0.8), size: 4,
                       props: { z: 1 } });
    }

    // A gust from behind blows the knob along: the one blowing its way takes the
    // travel, and the other, if a drag turned back, dies away.
    function slide(at, dx) {
        const g = dx > 0 ? gustRight : gustLeft;
        // Starting from still, or on another slider: the gust starts afresh.
        if (g.speed === 0 || Math.abs(g.at.y - at.y) > 4 || Math.abs(g.at.x - at.x) > 80) {
            g.speed = 0;
            g.build = 0;
            g.seed = Math.random();
        }
        g.at = at;
        g.lead = Math.min(Math.abs(dx), 40);
        g.push += Math.abs(dx);
        const dir = g.dir;
        const s = g.strength;
        // Specks and the odd leaf carried in it, by travel but never faster than a few a second.
        root.speckOwed += Math.abs(dx);
        if (root.speckOwed >= 40 && root.sinceSpeck > 0.08) {
            root.speckOwed = 0;
            root.sinceSpeck = 0;
            bits.emit(3, { x: at.x - dir * bits.rnd(14, 26 + 30 * s), y: at.y + bits.rnd(-6, 6), vx: dir * bits.rnd(160, 220 + 160 * s),
                           vy: bits.rnd(-25, 25), drag: 2, life: bits.rnd(0.35, 0.5), size: 6,
                           props: { z: 1 } });
        }
        root.leafOwed += Math.abs(dx);
        if (root.leafOwed >= root.leafEvery && root.sinceLeaf > 0.35) {
            root.leafOwed = 0;
            root.sinceLeaf = 0;
            root.leafEvery = bits.rnd(110, 170);
            root.leaf(at.x - dir * bits.rnd(18, 30), at.y - bits.rnd(2, 8), dir * bits.rnd(200, 280), -bits.rnd(70, 120));
        }
    }

    function release(at) {
        root.curl(at.x, at.y, 46);
        root.speck(at.x - 4, at.y - 6);
        root.speck(at.x + 5, at.y - 3);
    }

    function pick(area, at) {
        const cx = at.x, cy = at.y;
        const size = Math.max(44, Math.min(96, Math.max(area.width, area.height) * 2));
        root.curl(cx, cy, size);
        root.leaf(cx + size * 0.3, cy - size * 0.2, bits.rnd(40, 100), -bits.rnd(80, 140));
        root.wisp(cx - size * 0.4, cy + size * 0.15, 30, -60, 34);
        root.wisp(cx + size * 0.4, cy - size * 0.15, -30, 60, 34);
    }

    function toggle(area, on) {
        const x = on ? area.x + area.width - area.height / 2 : area.x + area.height / 2;
        const cy = area.y + area.height / 2;
        if (on) {
            root.curl(x, cy, 36);
            root.leaf(x, cy - 6, bits.rnd(40, 110), -bits.rnd(90, 150));
        } else {
            for (let i = 0; i < 3; i++)
                root.speck(x + bits.rnd(-6, 6), cy - bits.rnd(0, 8));
        }
    }

    // ── Gusts, one for each way a knob moves ────────────────
    component Gust: ShaderEffect {
        property real dir: 1
        property point at: Qt.point(-1000, -1000)
        // Travel this tick, px; how fast the knob goes, smoothed, px/s; 0..1 how long
        // it has blown; and px the air has streamed.
        property real push: 0
        property real speed: 0
        property real build: 0
        property real phase: 0
        readonly property bool blowing: speed > 4 || push > 0
        // Eases in with speed and saturates, so a fast drag is one strong gust, not a frantic one.
        readonly property real strength: 1 - Math.exp(-speed / 380)

        // `rival`: the other gust is blowing, so the drag turned back and this one dies fast.
        function step(dt, rival) {
            const target = Math.min(push / Math.max(dt, 0.004), 1500);
            push = 0;
            speed += (target - speed) * (1 - Math.exp(-dt * (target > speed ? 14 : rival ? 12 : 4.5)));
            if (speed < 4)
                speed = 0;
            build = Math.max(0, Math.min(1, build + dt * (target > 40 ? 1.6 : -1.2)));
            phase += dt * (70 + 170 * strength);
        }

        x: at.x - width / 2
        y: at.y - height / 2
        width: 260
        height: 64
        visible: speed > 0
        property size area: Qt.size(width, height)
        property real knob: 10
        property real lead: 0
        property real seed: 0
        property color cWind: root.theme.text
        fragmentShader: Qt.resolvedUrl("qsb/Interactions.gust.qsb")
    }

    Gust {
        id: gustRight
        dir: 1
    }

    Gust {
        id: gustLeft
        dir: -1
    }

    Loader {
        active: gustRight.blowing || gustLeft.blowing
        sourceComponent: Component {
            EffectClock {
                onAdvanced: dt => {
                    root.sinceSpeck += dt;
                    root.sinceLeaf += dt;
                    const right = gustRight.push > 0, left = gustLeft.push > 0;
                    gustRight.step(dt, left);
                    gustLeft.step(dt, right);
                }
            }
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
                property color cWind: root.theme.text
                property color cLeaf: root.theme.accent
                property color cLeafBack: root.theme.peach
                property color cOutline: root.theme.crust
                fragmentShader: Qt.resolvedUrl("qsb/Interactions.qsb")
            }
        }
    }
}
