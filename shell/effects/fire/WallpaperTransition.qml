import QtQuick
import "Flame.js" as Flame
import "common"

// Fire wallpaper transition: the old wallpaper catches near the middle of the screen,
// where the launcher was, and burns away outward to the new one in tongues of flame,
// leaving char that clears in steps behind the front and embers drifting up off it.
WallpaperStage {
    id: root

    // ── Choreography (seconds) ──────────────────────────────
    readonly property real spreadTime: 1.6
    // Flames go on burning 0.45 s after the front passes.
    duration: spreadTime + 0.45
    readonly property real fieldScale: 4

    readonly property color core: Flame.core(root.theme)

    readonly property real sweep: Math.min(1, root.clock.clock / root.spreadTime)
    // Embers owed to the burnt ground, paid out as the front passes over it.
    property real embersOwed: 0

    // Embers rise off ground the front has just passed, more as the front grows, and
    // burn out before the transition ends.
    function shedEmbers(dt) {
        const left = root.duration - root.clock.clock - 0.05;
        if (root.burnR < 60 || left < 0.3)
            return;
        root.embersOwed += dt * Math.min(90, root.burnR / 7);
        while (root.embersOwed >= 1) {
            root.embersOwed -= 1;
            const a = Math.random() * 2 * Math.PI;
            const r = root.burnR - embers.rnd(70, 260);
            const x = root.origin.x + Math.cos(a) * r, y = root.origin.y + Math.sin(a) * r;
            if (r < 0 || x < 0 || x > root.width || y < 0 || y > root.height)
                continue;
            embers.emit(4, { x: x, y: y, vx: embers.rnd(-30, 30), vy: -embers.rnd(60, 140), gravity: -embers.rnd(30, 80),
                             drag: 0.8, life: Math.min(left, embers.rnd(0.8, 1.4)), size: Math.round(embers.rnd(30, 46)),
                             props: { z: 2 } });
        }
    }
    readonly property point origin: Qt.point(width * 0.5, height * 0.55)
    // Past this radius the ragged front has cleared every screen corner.
    readonly property real maxRadius: Math.sqrt(Math.pow(width * 0.5 * 0.85, 2) + Math.pow(height * 0.55 * 1.15, 2))
        + 55 * fieldScale + 20
    // Fire spreads slowly at first, races outward, and slows as it reaches the corners.
    readonly property real spread: sweep * sweep * (2.2 - 1.2 * sweep)
    readonly property real burnR: -20 + spread * (maxRadius + 20)
    // How fast the front moves (px/s), so flames keep up with it: they burn out a
    // seventh of a second's travel behind it, the revealed wallpaper clearing behind them.
    readonly property real frontSpeed: sweep * (4.4 - 3.6 * sweep) * (maxRadius + 20) / spreadTime

    onAdvanced: dt => {
        if (root.sweep < 1)
            root.shedEmbers(dt);
    }

    ShaderEffect {
        anchors.fill: parent
        visible: root.sweep < 1
        property var source: root.outgoingTexture
        property rect rect: Qt.rect(0, 0, width, height)
        property point revealOrigin: root.origin
        property real revealR: 1e5
        property point burnOrigin: root.origin
        property real burnR: root.burnR
        property real refill: 0
        property real fade: 0
        property real fieldScale: root.fieldScale
        property color cGlow: Flame.glow(root.theme)
        property color cHot: root.core
        property color cChar: Flame.charred(root.theme, true)
        property color cScorch: Flame.scorch(root.theme)
        property real soot: 1
        fragmentShader: Qt.resolvedUrl("qsb/Burn.qsb")
    }

    Flames {
        theme: root.theme
        anchors.fill: parent
        time: root.clock.simTime
        // The front burns down as it reaches the corners, so its flames die out with it.
        frontFuel: 1 - 0.75 * Math.max(0, Math.min(1, (root.sweep - 0.7) / 0.3))
        panelRect: Qt.rect(0, 0, root.width, root.height)
        origin: root.origin
        burnR: root.burnR
        fieldScale: root.fieldScale
        clearBehind: false
        trail: 50 + 0.08 * root.frontSpeed
    }

    // The controls' ember, larger.
    Particles {
        id: embers
        anchors.fill: parent
        capacity: 96
        delegate: Component {
            ShaderEffect {
                property real age: 0
                property real seed: 0
                property real kind: 4
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
