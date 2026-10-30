import QtQuick
import "common"
import "common/Colors.js" as Colors

// Cosmos's effects on Speshell's controls. A knob dragged along a slider leaves a
// trail of star dust that twinkles out, with now and then a glint; let go, a star
// flares where it stops. Picking something draws a constellation out from the pointer,
// star by star, off the control so it never lies over its label. A switch turned on flares and strings a few stars off it; turned off,
// a little dust drifts off it.
Item {
    id: root

    // ── Speshell effects API v1: interactions ───────────────
    property var theme: null

    // Travel not yet paid out in dust and glints, px.
    property real dustOwed: 0
    property real glintOwed: 0
    property real glintEvery: 60

    function rnd(a, b) {
        return a + Math.random() * (b - a);
    }

    function mote(x, y, vx, vy) {
        bits.spawn({ x: x, y: y, vx: vx, vy: vy, drag: 2, life: rnd(0.5, 0.9), size: Math.round(rnd(4, 7)),
                     props: { kind: 0, seed: Math.random(), z: 1 } });
    }

    function glint(x, y, size) {
        bits.spawn({ x: x, y: y, life: 0.4, size: size, props: { kind: 1, seed: Math.random(), z: 2 } });
    }

    // Stars strung out from (x, y) one by one; `room` px above it to lean into, and
    // `area` (if any) the control to keep off.
    function constellation(x, y, size, life, room, area) {
        var keepOff = area ? Qt.vector4d(area.x - x, area.y - y, area.width, area.height) : Qt.vector4d(0, 0, 0, 0);
        bits.spawn({ x: x, y: y, life: life, size: size, props: { kind: 2, seed: Math.random(), room: room, keepOff: keepOff, z: 1 } });
    }

    function burst(x, y, count, speed) {
        for (var i = 0; i < count; i++) {
            var a = (i + Math.random() * 0.8) / count * 2 * Math.PI;
            var v = rnd(0.5, 1) * speed;
            root.mote(x, y, Math.cos(a) * v, Math.sin(a) * v);
        }
    }

    function slide(at, dx) {
        var back = dx > 0 ? -1 : 1;
        root.dustOwed = Math.min(root.dustOwed + Math.abs(dx), 30);
        while (root.dustOwed >= 5) {
            root.dustOwed -= 5;
            root.mote(at.x + back * rnd(2, 8), at.y + rnd(-7, 7), back * rnd(5, 35), rnd(-20, 20));
        }
        root.glintOwed += Math.abs(dx);
        if (root.glintOwed >= root.glintEvery) {
            root.glintOwed = 0;
            root.glintEvery = rnd(40, 90);
            root.glint(at.x + back * rnd(6, 14), at.y + rnd(-8, 8), Math.round(rnd(14, 20)));
        }
    }

    function release(at) {
        root.glint(at.x, at.y, 28);
        root.burst(at.x, at.y, 4, 70);
    }

    function pick(area, at) {
        root.constellation(at.x, at.y, 130, 1.0, at.y, area);
    }

    function toggle(area, on) {
        var x = on ? area.x + area.width - area.height / 2 : area.x + area.height / 2;
        var cy = area.y + area.height / 2;
        if (on) {
            root.glint(x, cy, 26);
            root.constellation(x, cy, 76, 0.8, cy);
        } else {
            root.mote(x - 2, cy - 4, -15, -25);
            root.mote(x + 2, cy - 2, 15, -20);
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
                property color cStar: root.theme ? root.theme.text : "#ebdbb2"
                property color cHot: root.theme ? Qt.lighter(Colors.mix(root.theme.text, root.theme.yellow, 0.15), 1.2) : "#fbf1c7"
                property color cGlow: root.theme ? root.theme.accent : "#fe8019"
                property color cHaze: root.theme ? root.theme.pink : "#d3869b"
                property real room: 10000
                property vector4d keepOff: Qt.vector4d(0, 0, 0, 0)
                fragmentShader: Qt.resolvedUrl("qsb/Interactions.qsb")
            }
        }
    }
}
