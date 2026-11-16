import QtQuick
import "common/Colors.js" as Colors
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
    property var theme: Colors.fallback

    // Travel not yet paid out in streaks and flames, px.
    property real streakOwed: 0
    property real flameOwed: 0

    // Starts a particle of `kind` (see common/Particles.qml), `alpha` solid (1 unless given).
    function put(kind, p, alpha) {
        p.props.alpha = alpha === undefined ? 1 : alpha;
        bits.emit(kind, p);
    }

    function tongue(x, y, vx, size) {
        root.put(0, { x: x, y: y, vx: vx, vy: -bits.rnd(10, 70), gravity: -bits.rnd(90, 220), drag: 2,
                      life: bits.rnd(0.3, 0.6), size: size, props: { z: 1 } });
    }

    function spark(x, y, vx, vy) {
        root.put(1, { x: x, y: y, vx: vx, vy: vy, gravity: 380, life: bits.rnd(0.35, 0.6), size: 12, orient: true,
                      props: { z: 2 } });
    }

    // A flame standing where it was lit, its base on the track.
    function trailFlame(x, y, size) {
        root.put(0, { x: x, y: y - size * 0.28, life: bits.rnd(0.4, 0.7), size: size, props: { z: 1 } });
    }

    function streak(x, y) {
        root.put(3, { x: x, y: y, life: bits.rnd(0.55, 0.7), size: 18, props: { z: 0 } });
    }

    function smoke(x, y, vx, alpha) {
        root.put(2, { x: x, y: y, vx: vx, vy: -bits.rnd(30, 50), drag: 2, life: bits.rnd(0.6, 0.8), size: 20,
                      props: { z: 0 } }, alpha);
    }

    function slide(at, dx) {
        const back = dx > 0 ? -1 : 1;
        root.streakOwed = Math.min(root.streakOwed + Math.abs(dx), 48);
        while (root.streakOwed >= 8) {
            root.streakOwed -= 8;
            root.streak(at.x + back * (root.streakOwed + 4), at.y);
        }
        root.flameOwed = Math.min(root.flameOwed + Math.abs(dx), 48);
        while (root.flameOwed >= 9) {
            root.flameOwed -= 9;
            root.trailFlame(at.x + back * (root.flameOwed + bits.rnd(4, 9)), at.y, Math.round(bits.rnd(13, 24)));
            if (Math.random() < 0.2)
                root.spark(at.x + back * 6, at.y - 4, back * bits.rnd(30, 110) + bits.rnd(-30, 30), -bits.rnd(140, 280));
        }
    }

    function release(at) {
        for (let i = 0; i < 5; i++)
            root.spark(at.x, at.y - 3, bits.rnd(-110, 110), -bits.rnd(170, 320));
        root.tongue(at.x, at.y - 3, 0, 22);
    }

    function ember(x, y, delay) {
        root.put(4, { x: x, y: y, vx: bits.rnd(-25, 25), vy: -bits.rnd(40, 90), gravity: -bits.rnd(40, 90), drag: 1.2,
                      life: bits.rnd(0.6, 1.0), delay: delay, size: Math.round(bits.rnd(9, 13)),
                      props: { z: 2 } });
    }

    function flash(x, y, size, life, alpha) {
        root.put(5, { x: x, y: y, life: life, size: size, props: { z: 2 } }, alpha);
    }

    // A flash where it lit, flames standing on (x, y) at `scale`, embers floating up.
    function ignite(x, y, scale, embers) {
        root.flash(x, y, Math.round(26 * scale), 0.2);
        const sizes = [28, 21, 18];
        const offsets = [0, -7, 7];
        for (let i = 0; i < 3; i++) {
            const size = Math.round(sizes[i] * scale);
            root.put(0, { x: x + (offsets[i] + bits.rnd(-2, 2)) * scale, y: y - size * 0.28, vy: -bits.rnd(5, 15),
                          life: bits.rnd(0.45, 0.65), delay: 0.03 + i * 0.04, size: size,
                          props: { z: 1 } });
        }
        for (let j = 0; j < embers; j++)
            root.ember(x + bits.rnd(-8, 8) * scale, y - bits.rnd(2, 10) * scale, 0.08 + j * 0.06);
    }

    function pick(area, at) {
        root.flash(at.x, at.y, 16, 0.14, 0.45);
        const size = Math.round(bits.rnd(17, 21));
        root.put(0, { x: at.x + bits.rnd(-1.5, 1.5), y: at.y - size * 0.28, vy: -bits.rnd(5, 15), life: bits.rnd(0.3, 0.4),
                      delay: 0.02, size: size, props: { z: 1 } }, 0.5);
        // Embers rising quickly off it, out of the line of text.
        for (let j = 0; j < 5; j++)
            root.put(4, { x: at.x + bits.rnd(-5, 5), y: at.y - bits.rnd(2, 6), vx: bits.rnd(-55, 55), vy: -bits.rnd(110, 170),
                          gravity: -bits.rnd(20, 60), drag: 1.4, life: bits.rnd(0.6, 0.9), delay: 0.04 + j * 0.05,
                          size: Math.round(bits.rnd(8, 11)), props: { z: 2 } });
        root.smoke(at.x, at.y - 22, bits.rnd(-8, 8), 0.7);
    }

    function toggle(area, on) {
        const x = on ? area.x + area.width - area.height / 2 : area.x + area.height / 2;
        const cy = area.y + area.height / 2;
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
                property color cSmoke: root.theme.overlay
                property color cGlint: root.theme.text
                fragmentShader: Qt.resolvedUrl("qsb/Interactions.qsb")
            }
        }
    }
}
