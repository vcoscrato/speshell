import QtQuick
import "common/Colors.js" as Colors
import "common"

// Water's effects on Speshell's controls. A knob dragged down a slider pours
// water out: it drips and runs off the track it leaves empty. Dragged up, water pours
// in: drops fall onto the track it fills and splash there. Either way it ripples the
// track now and then; let go, it rings out in one more. Picking something drops water
// onto the pointer: it splashes up in a crown, flings drops that land in ripples all
// around, and leaps back up in a jet. A switch turned on splashes the same, smaller;
// turned off, it ripples and drips.
Item {
    id: root

    // ── Speshell effects API v1: interactions ───────────────
    property var theme: Colors.fallback

    // Travel not yet paid out in drops and ripples, px.
    property real dropOwed: 0
    property real rippleOwed: 0
    property real rippleEvery: 30

    function drop(x, y, vx, vy) {
        bits.emit(0, { x: x, y: y, vx: vx, vy: vy, gravity: 900, life: bits.rnd(0.4, 0.6), size: Math.round(bits.rnd(7, 11)),
                       orient: true, props: { arrive: 0, z: 2 } });
    }

    // A drop falling from the track, slow to let go.
    function drip(x, y, size, delay) {
        bits.emit(0, { x: x, y: y, vx: bits.rnd(-8, 8), vy: bits.rnd(10, 60), gravity: 1100, life: bits.rnd(0.45, 0.6), delay: delay,
                       size: size, orient: true, props: { arrive: 0, z: 2 } });
    }

    // A drop poured in from above, landing on (tx, ty) after `t` seconds with a splash.
    function pour(tx, ty, t) {
        const g = 1400, x = tx + bits.rnd(-4, 4), y = ty - bits.rnd(46, 72);
        bits.emit(0, { x: x, y: y, vx: (tx - x) / t, vy: (ty - y) / t - 0.5 * g * t, gravity: g, life: t,
                       size: Math.round(bits.rnd(15, 20)), orient: true, props: { arrive: 1, z: 2 } });
        bits.emit(1, { x: tx, y: ty, life: 0.3, delay: t, size: Math.round(bits.rnd(16, 22)),
                       props: { squash: 0.35, z: 0 } });
        if (Math.random() < 0.5) {
            for (let i = 0; i < 2; i++)
                bits.emit(0, { x: tx, y: ty - 2, vx: bits.rnd(-80, 80), vy: -bits.rnd(90, 150), gravity: 900, life: bits.rnd(0.2, 0.3),
                               delay: t, size: 6, orient: true, props: { arrive: 0, z: 2 } });
        }
    }

    function ripple(x, y, size, squash, delay) {
        bits.emit(1, { x: x, y: y, life: 0.55, delay: delay || 0, size: size,
                       props: { squash: squash, z: 0 } });
    }

    function slide(at, dx) {
        const back = dx > 0 ? -1 : 1;
        const every = dx < 0 ? 5 : 8;
        root.dropOwed = Math.min(root.dropOwed + Math.abs(dx), 48);
        while (root.dropOwed >= every) {
            root.dropOwed -= every;
            if (dx < 0) {
                // Down: the track just emptied pours off its underside.
                root.drip(at.x + root.dropOwed + bits.rnd(2, 8), at.y + 4, Math.round(bits.rnd(10, 15)), bits.rnd(0, 0.05));
            } else {
                // Up: water pours onto the track just filled.
                root.pour(at.x - root.dropOwed - bits.rnd(4, 22), at.y + 1, bits.rnd(0.16, 0.22));
            }
        }
        root.rippleOwed += Math.abs(dx);
        if (root.rippleOwed >= root.rippleEvery) {
            root.rippleOwed = 0;
            root.rippleEvery = bits.rnd(24, 48);
            root.ripple(at.x + back * bits.rnd(0, 6), at.y + bits.rnd(1, 4), Math.round(bits.rnd(26, 44)), bits.rnd(0.28, 0.42));
        }
    }

    function release(at) {
        root.ripple(at.x, at.y + 2, 48, 0.35);
        for (let i = 0; i < 3; i++)
            root.drop(at.x, at.y - 3, bits.rnd(-80, 80), -bits.rnd(160, 240));
    }

    // A drop flung from (x, y) at (vx, vy) after `delay` s that lands on the surface
    // `ground` px lower and ripples there.
    function fling(x, y, vx, vy, ground, size, delay) {
        const g = 900, t = (-vy + Math.sqrt(vy * vy + 2 * g * Math.max(0, ground))) / g;
        bits.emit(0, { x: x, y: y, vx: vx, vy: vy, gravity: g, life: t, delay: delay, size: size, orient: true,
                       props: { arrive: 2, z: 2 } });
        root.ripple(x + vx * t, y + ground, Math.round(size * bits.rnd(1.6, 2.4)), 0.3, delay + t);
    }

    // A drop falls onto (x, y) at a slant: a crown splashes up, leaning the way it went,
    // drops fly off and ripple where they land, spray hangs, and a jet may leap back up.
    function splash(x, y, scale, jet) {
        const t = 0.13, g = 1400, fall = Math.min(70, y + 14) * scale;
        const vx = bits.rnd(-70, 70) * scale;
        bits.emit(0, { x: x - vx * t, y: y - fall, vx: vx, vy: fall / t - 0.5 * g * t, gravity: g, life: t,
                       size: Math.round(16 * scale), orient: true, props: { arrive: 1, z: 2 } });
        const lean = vx / 70;
        bits.emit(2, { x: x, y: y, life: 0.42, delay: t, size: Math.round(46 * scale),
                       props: { lean: lean, z: 1 } });
        root.ripple(x, y + 2, Math.round(50 * scale), 0.3, t + 0.04);
        root.ripple(x + vx * 0.08, y + 3, Math.round(bits.rnd(56, 70) * scale), 0.28, t + 0.2);
        const flung = Math.round(bits.rnd(6, 10) * scale);
        for (let i = 0; i < flung; i++) {
            // Mostly the way the drop was going, some back, a few high.
            const a = -Math.PI / 2 + bits.rnd(-1.35, 1.35) + lean * 0.4;
            const v = bits.rnd(70, 220) * Math.sqrt(scale);
            const size = Math.round(bits.rnd(4, 10) * Math.sqrt(scale));
            root.fling(x, y - 3, Math.cos(a) * v, Math.sin(a) * v, bits.rnd(-1, 8) * scale + 3, size, t + bits.rnd(0.02, 0.09));
        }
        for (let j = 0; j < 6; j++) {
            const b = -Math.PI / 2 + bits.rnd(-1.5, 1.5);
            const sv = bits.rnd(150, 300) * scale;
            bits.emit(0, { x: x, y: y - 2, vx: Math.cos(b) * sv, vy: Math.sin(b) * sv, drag: 5, gravity: 300, delay: t,
                           life: bits.rnd(0.2, 0.35), size: 4, orient: true, props: { arrive: 0, z: 2 } });
        }
        if (jet)
            bits.emit(3, { x: x, y: y - 0.9 * 15 * scale, life: 0.55, delay: t + 0.16, size: Math.round(30 * scale),
                           props: { lean: bits.rnd(-0.35, 0.35) + lean * 0.2, z: 1 } });
        // Now and then a smaller drop follows it in, off to the side.
        if (Math.random() < 0.6) {
            const ox = bits.rnd(8, 16) * (Math.random() < 0.5 ? -1 : 1) * scale;
            bits.emit(0, { x: x + ox - vx * t, y: y - fall, vx: vx, vy: fall / t - 0.5 * g * t, gravity: g, life: t, delay: 0.07,
                           size: Math.round(9 * scale), orient: true, props: { arrive: 1, z: 2 } });
            root.ripple(x + ox, y + 3, Math.round(28 * scale), 0.32, t + 0.07);
            for (let k = 0; k < 2; k++)
                root.fling(x + ox, y + 1, bits.rnd(-70, 70), -bits.rnd(90, 150), 3, 5, t + 0.07);
        }
    }

    function pick(area, at) {
        root.splash(at.x, at.y, 1, true);
    }

    function toggle(area, on) {
        const x = on ? area.x + area.width - area.height / 2 : area.x + area.height / 2;
        const cy = area.y + area.height / 2;
        if (on) {
            root.splash(x, cy, 0.6, false);
        } else {
            root.ripple(x, cy + area.height / 2, 40, 0.35);
            root.drop(x, cy + 4, bits.rnd(-20, 20), 40);
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
                property real arrive: 0
                property real squash: 1
                property real lean: 0
                property color cWater: root.theme.accent
                property color cLight: root.theme.sky
                property color cFoam: root.theme.text
                property color cDeep: root.theme.crust
                fragmentShader: Qt.resolvedUrl("qsb/Interactions.qsb")
            }
        }
    }
}
