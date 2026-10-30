import QtQuick
import "Flame.js" as Flame
import "common"

// Fire's effects on Speshell's controls. A knob dragged along a slider sets the
// track alight behind it: a burning streak with flames standing on it that die down
// as it cools, throwing the odd spark; let go, it spits a few more. Picking something
// lights it under the pointer without hiding it: a brief flash and a low flame you can
// see through, embers rising off it clear of the text, and a wisp of smoke. A switch
// turned on catches in full; turned off, it goes out in smoke.
Item {
    id: root

    // ── Speshell effects API v1: interactions ───────────────
    property var theme: null

    // Travel not yet paid out in streaks and flames, px.
    property real streakOwed: 0
    property real flameOwed: 0

    function rnd(a, b) {
        return a + Math.random() * (b - a);
    }

    // Spawns a particle (see common/Particles.qml), `alpha` solid (1 unless given).
    function put(p, alpha) {
        p.props.alpha = alpha === undefined ? 1 : alpha;
        bits.spawn(p);
    }

    function tongue(x, y, vx, size) {
        root.put({ x: x, y: y, vx: vx, vy: -rnd(10, 70), gravity: -rnd(90, 220), drag: 2, life: rnd(0.3, 0.6),
                   size: size, props: { kind: 0, seed: Math.random(), z: 1 } });
    }

    function spark(x, y, vx, vy) {
        root.put({ x: x, y: y, vx: vx, vy: vy, gravity: 380, life: rnd(0.35, 0.6), size: 12, orient: true,
                   props: { kind: 1, seed: Math.random(), z: 2 } });
    }

    // A flame standing where it was lit, its base on the track.
    function trailFlame(x, y, size) {
        root.put({ x: x, y: y - size * 0.28, life: rnd(0.4, 0.7), size: size,
                   props: { kind: 0, seed: Math.random(), z: 1 } });
    }

    function streak(x, y) {
        root.put({ x: x, y: y, life: rnd(0.55, 0.7), size: 18, props: { kind: 3, seed: Math.random(), z: 0 } });
    }

    function smoke(x, y, vx, alpha) {
        root.put({ x: x, y: y, vx: vx, vy: -rnd(30, 50), drag: 2, life: rnd(0.6, 0.8), size: 20,
                   props: { kind: 2, seed: Math.random(), z: 0 } }, alpha);
    }

    function slide(at, dx) {
        var back = dx > 0 ? -1 : 1;
        root.streakOwed = Math.min(root.streakOwed + Math.abs(dx), 48);
        while (root.streakOwed >= 8) {
            root.streakOwed -= 8;
            root.streak(at.x + back * (root.streakOwed + 4), at.y);
        }
        root.flameOwed = Math.min(root.flameOwed + Math.abs(dx), 48);
        while (root.flameOwed >= 9) {
            root.flameOwed -= 9;
            root.trailFlame(at.x + back * (root.flameOwed + rnd(4, 9)), at.y, Math.round(rnd(13, 24)));
            if (Math.random() < 0.2)
                root.spark(at.x + back * 6, at.y - 4, back * rnd(30, 110) + rnd(-30, 30), -rnd(140, 280));
        }
    }

    function release(at) {
        for (var i = 0; i < 5; i++)
            root.spark(at.x, at.y - 3, rnd(-110, 110), -rnd(170, 320));
        root.tongue(at.x, at.y - 3, 0, 22);
    }

    function ember(x, y, delay) {
        root.put({ x: x, y: y, vx: rnd(-25, 25), vy: -rnd(40, 90), gravity: -rnd(40, 90), drag: 1.2,
                   life: rnd(0.6, 1.0), delay: delay, size: Math.round(rnd(9, 13)),
                   props: { kind: 4, seed: Math.random(), z: 2 } });
    }

    function flash(x, y, size, life, alpha) {
        root.put({ x: x, y: y, life: life, size: size, props: { kind: 5, seed: Math.random(), z: 2 } }, alpha);
    }

    // A flash where it lit, flames standing on (x, y) at `scale`, embers floating up.
    function ignite(x, y, scale, embers) {
        root.flash(x, y, Math.round(26 * scale), 0.2);
        var sizes = [28, 21, 18];
        var offsets = [0, -7, 7];
        for (var i = 0; i < 3; i++) {
            var size = Math.round(sizes[i] * scale);
            root.put({ x: x + (offsets[i] + rnd(-2, 2)) * scale, y: y - size * 0.28, vy: -rnd(5, 15),
                       life: rnd(0.45, 0.65), delay: 0.03 + i * 0.04, size: size,
                       props: { kind: 0, seed: Math.random(), z: 1 } });
        }
        for (var j = 0; j < embers; j++)
            root.ember(x + rnd(-8, 8) * scale, y - rnd(2, 10) * scale, 0.08 + j * 0.06);
    }

    function pick(area, at) {
        root.flash(at.x, at.y, 16, 0.14, 0.45);
        var size = Math.round(rnd(17, 21));
        root.put({ x: at.x + rnd(-1.5, 1.5), y: at.y - size * 0.28, vy: -rnd(5, 15), life: rnd(0.3, 0.4),
                   delay: 0.02, size: size, props: { kind: 0, seed: Math.random(), z: 1 } }, 0.5);
        // Embers rising quickly off it, out of the line of text.
        for (var j = 0; j < 5; j++)
            root.put({ x: at.x + rnd(-5, 5), y: at.y - rnd(2, 6), vx: rnd(-55, 55), vy: -rnd(110, 170),
                       gravity: -rnd(20, 60), drag: 1.4, life: rnd(0.6, 0.9), delay: 0.04 + j * 0.05,
                       size: Math.round(rnd(8, 11)), props: { kind: 4, seed: Math.random(), z: 2 } });
        root.smoke(at.x, at.y - 22, rnd(-8, 8), 0.7);
    }

    function toggle(area, on) {
        var x = on ? area.x + area.width - area.height / 2 : area.x + area.height / 2;
        var cy = area.y + area.height / 2;
        if (on) {
            root.ignite(x, cy, 0.7, 3);
        } else {
            root.smoke(x - 4, cy - 6, -15);
            root.smoke(x + 4, cy - 10, 15);
        }
    }

    Particles {
        id: bits
        anchors.fill: parent
        capacity: 128
        delegate: Component {
            ShaderEffect {
                property real age: 0
                property real seed: 0
                property real kind: 0
                property real size: width
                property real alpha: 1
                property color cCore: Flame.core(root.theme)
                property color cMid: Flame.mid(root.theme)
                property color cOuter: Flame.outer(root.theme)
                property color cEdge: Flame.edge(root.theme)
                property color cSmoke: root.theme ? root.theme.overlay : "#8a5048"
                property color cGlint: root.theme ? root.theme.text : "#f3e3d3"
                fragmentShader: Qt.resolvedUrl("qsb/Interactions.qsb")
            }
        }
    }
}
