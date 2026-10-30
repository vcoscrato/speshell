import QtQuick
import "Flame.js" as Flame
import "common"

// Fire launcher transition: an ember flares and throws sparks, a burning edge sweeps the panel into
// view, and flames simmer around it while open, embers drifting up off them, now and
// then a curl of smoke, and their warm light on the air over the panel. Closing burns a hole through the
// middle of the panel that spreads outward until it is gone. Reopening mid-exit
// opens it the usual way: the hole's burning edge dies down while a new front sweeps
// in from the ember's corner and fills the hole, the unburnt panel staying put.
// Closing again before it is done sweeps that front back, then the hole burns on.
Item {
    id: root

    // ── Speshell effects API v1 ────────────────────────────────
    property Item panel: null
    property rect panelRect
    property bool active: false
    // The active palette, as Theme.qml names it.
    property var theme: null
    signal closingFinished()

    // ── Choreography (seconds) ──────────────────────────────
    readonly property real igniteTime: 0.22
    readonly property real sweepTime: 0.8
    readonly property real burnTime: 0.55
    readonly property real tailTime: 0.35     // flames left burning after the panel is gone
    readonly property real simmer: 0.55       // rim flame strength while open
    readonly property real emberRate: 9       // embers off the crown per second while open

    readonly property color core: Flame.core(root.theme)

    property real phaseStart: 0
    property bool sparkPending: true
    property bool exitDone: false
    property bool closedOnce: false   // a reopen mid-exit has no ember
    // Embers not yet thrown off the crown, and seconds to the next curl of smoke.
    property real embersOwed: 0
    property real nextSmoke: 1.2
    // The flames' light, easing after how fully they simmer.
    property real glow: 0

    // sweep: 0..1 progress of the entrance front; burn: 0..1 progress of the exit hole;
    // refill: reopened mid-exit, the entrance front is filling the hole.
    property real sweep: 0
    property real burn: 0
    property bool refill: false
    readonly property point revealOrigin: Qt.point(panelRect.x + panelRect.width * 0.22,
                                                   panelRect.y + panelRect.height * 0.82)
    readonly property point burnOrigin: Qt.point(panelRect.x + panelRect.width * 0.5,
                                                 panelRect.y + panelRect.height * 0.55)
    // Past these radii the ragged fronts have cleared every panel corner.
    readonly property real revealMax: Math.sqrt(Math.pow(panelRect.width * 0.78 * 0.85, 2)
                                                + Math.pow(panelRect.height * 0.82 * 1.15, 2)) + 90
    readonly property real burnMax: Math.sqrt(Math.pow(panelRect.width * 0.5 * 0.85, 2)
                                              + Math.pow(panelRect.height * 0.55 * 1.15, 2)) + 90
    readonly property real revealR: -30 + (1 - Math.pow(1 - sweep, 1.5)) * (revealMax + 30)
    // Slow to catch, then racing outward.
    readonly property real burnR: -20 + Math.pow(burn, 1.3) * (burnMax + 20)
    readonly property bool capturing: sweep < 1 || burn > 0
    readonly property real phaseAge: clock.clock - phaseStart
    // 0..1 how fully the flames simmer round the open panel.
    readonly property real simmering: root.active && !root.refill ? Math.max(0, Math.min(1, (root.sweep - 0.5) / 0.5)) : 0

    onActiveChanged: {
        phaseStart = clock.clock;
        exitDone = false;
        if (!active)
            closedOnce = true;
        // Reopened mid-exit: the entrance front starts over at once, filling the hole.
        if (active && burn > 0 && !refill) {
            refill = true;
            sweep = 0;
            sparkPending = false;
        }
    }

    EffectClock {
        id: clock
        onAdvanced: function(dt) {
            root.glow += (root.simmering - root.glow) * Math.min(1, dt * 5);
            if (root.active) {
                if (root.sparkPending && root.phaseAge < root.igniteTime)
                    return;
                root.sparkPending = false;
                root.sweep = Math.min(1, root.sweep + dt / root.sweepTime);
                root.simmerBits(dt);
                // Past the panel's corners the hole is filled and the panel whole.
                if (root.refill && root.sweep >= 1) {
                    root.refill = false;
                    root.burn = 0;
                }
            } else if (root.refill) {
                // Closed again while filling: the front sweeps back, then the hole burns on.
                root.sweep = Math.max(0, root.sweep - 1.6 * dt / root.sweepTime);
                root.phaseStart = clock.clock;
                if (root.sweep <= 0) {
                    root.refill = false;
                    root.sweep = 1;
                }
            } else if (root.burn < 1) {
                root.burn = Math.min(1, root.burn + dt / root.burnTime);
                root.phaseStart = clock.clock;
            } else if (!root.exitDone && root.phaseAge >= root.tailTime) {
                root.exitDone = true;
                // Speshell may destroy this item inside the signal, so nothing may follow it.
                root.closingFinished();
            }
        }
    }

    function rnd(a, b) {
        return a + Math.random() * (b - a);
    }

    // While it simmers: embers thrown up off the crown, and now and then a curl of smoke.
    function simmerBits(dt) {
        if (root.simmering <= 0)
            return;
        var r = root.panelRect;
        root.embersOwed += dt * root.emberRate * root.simmering;
        while (root.embersOwed >= 1) {
            root.embersOwed -= 1;
            // Some small and quick, a few larger and lazier, swaying as they rise.
            var big = Math.random() < 0.25;
            bits.spawn({ x: r.x + r.width * rnd(0.04, 0.96), y: r.y - rnd(6, 18), vx: rnd(-18, 18),
                         vy: -rnd(30, big ? 60 : 110), gravity: -rnd(10, 50), drag: 0.6,
                         life: rnd(big ? 1.6 : 0.9, big ? 2.4 : 1.6), size: Math.round(big ? rnd(15, 19) : rnd(10, 13)),
                         props: { kind: 4, seed: Math.random(), z: 1 } });
        }
        root.nextSmoke -= dt;
        if (root.nextSmoke <= 0) {
            root.nextSmoke = rnd(2.5, 5);
            var x = r.x + r.width * rnd(0.15, 0.85), drift = rnd(-14, 14);
            for (var i = 0; i < 3; i++)
                bits.spawn({ x: x + drift * i * 0.4, y: r.y - 20 - i * 6, vx: drift + rnd(-6, 6), vy: -rnd(24, 36),
                             drag: 0.4, life: rnd(1.4, 1.9), delay: i * 0.22, size: Math.round(30 + 10 * i),
                             props: { kind: 2, seed: Math.random(), z: 0 } });
        }
    }

    // The flames' warm light on the air over the panel's top edge, under them.
    ShaderEffect {
        readonly property real reach: 70
        visible: strength > 0.005
        x: root.panelRect.x - 40
        y: root.panelRect.y - reach
        width: root.panelRect.width + 80
        height: reach
        property size resolution: Qt.size(width, height)
        property real edge: reach
        property real inset: 40
        property real time: clock.simTime
        property real strength: root.glow
        property color cGlow: Flame.glow(root.theme)
        fragmentShader: Qt.resolvedUrl("qsb/LauncherTransition.glow.qsb")
    }

    Flames {
        theme: root.theme
        anchors.fill: parent
        readonly property bool exiting: root.burn > 0 && !root.refill
        readonly property real kindled: exiting ? 0 : root.sweep
        time: clock.simTime
        emit: root.active ? root.simmer * Math.max(0, Math.min(1, (kindled - 0.5) / 0.5)) : 0
        frontFuel: (root.sweep > 0 && root.sweep < 1) || (exiting && root.burn < 1) ? 1 : 0
        panelRect: root.panelRect
        origin: exiting ? root.burnOrigin : root.revealOrigin
        burnR: exiting ? root.burnR : root.revealR
        core: root.core
    }

    // Embers and smoke off the crown, over the flames; gone quickly once it closes.
    Particles {
        id: bits
        anchors.fill: parent
        opacity: root.active ? 1 : Math.max(0, 1 - root.burn * 2.5)
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

    // ── The panel between the fronts; otherwise the real panel shows ──
    ShaderEffectSource {
        id: panelTex
        sourceItem: root.panel
        hideSource: root.capturing
        live: root.capturing
    }

    ShaderEffect {
        visible: root.capturing && root.panel !== null
        x: root.panelRect.x
        y: root.panelRect.y
        width: root.panelRect.width
        height: root.panelRect.height
        property var source: panelTex
        property rect rect: root.panelRect
        property point revealOrigin: root.revealOrigin
        property real revealR: root.revealR
        property point burnOrigin: root.burnOrigin
        property real burnR: root.burn > 0 ? root.burnR : -1e5
        property real refill: root.refill ? 1 : 0
        // The hole's burning edge dies down as the front sets out.
        property real fade: root.refill ? Math.min(1, root.sweep * 3) : 0
        property real fieldScale: 1
        property color cGlow: Flame.glow(root.theme)
        property color cHot: root.core
        property color cChar: Flame.charred(root.theme, false)
        property color cScorch: Flame.scorch(root.theme)
        fragmentShader: Qt.resolvedUrl("qsb/Burn.qsb")
    }

    // ── Ignition ember: flares, throws sparks, and collapses as the front sets out ──
    ShaderEffect {
        visible: root.active && !root.closedOnce && root.phaseAge < root.igniteTime + 0.3
        x: root.revealOrigin.x - width / 2
        y: root.revealOrigin.y - height / 2
        width: 240
        height: 240
        property size resolution: Qt.size(width, height)
        property real age: root.phaseAge
        property real ignite: root.igniteTime
        property color cCore: root.core
        property color cMid: Flame.mid(root.theme)
        property color cOuter: Flame.outer(root.theme)
        property color cEdge: Flame.edge(root.theme)
        property color cGlow: Flame.glow(root.theme)
        fragmentShader: Qt.resolvedUrl("qsb/LauncherTransition.ember.qsb")
    }
}
