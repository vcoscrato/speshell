import QtQuick
import "common"
import "common/Colors.js" as Colors
import "Cosmos.js" as Cosmos

// Cosmos launcher transition: a star flares where the panel will be, and the panel
// opens out of it behind a bright ring while planets spiral out to their orbits.
// While open, a small orrery turns round the panel, which stands in its plane as
// the sun: planets pass behind it and below it, dust drifts in a belt, stars
// twinkle, and a comet swings by now and then. Closing collapses the panel back
// into the star, the planets falling in after it.
Item {
    id: root

    // ── Speshell effects API v1 ────────────────────────────────
    property Item panel: null
    property rect panelRect
    property real panelRadius: 16
    property bool active: false
    // The active palette, as Theme.qml names it.
    property var theme: Colors.fallback
    signal closingFinished()

    // ── Choreography (seconds) ──────────────────────────────
    readonly property real flareTime: 0.16
    readonly property real openTime: 0.6
    readonly property real closeTime: 0.42
    readonly property real tailTime: 0.24      // the star fading after the panel is gone

    // ── Palette, from the theme ─────────────────────────────
    readonly property color hot: Cosmos.hot(root.theme)
    readonly property color warm: root.theme.accent
    readonly property color gold: root.theme.yellow
    readonly property color violet: root.theme.pink

    // 0..1 entrance progress; the exit runs it backwards, so a reopen mid-exit
    // simply turns around.
    property real open: 0
    property real flare: 0
    property bool flaring: true
    property real tail: 0
    property bool exitDone: false
    property real time: 0

    // Orbit periods (seconds) and angles of the five planets, and the moon's.
    readonly property var periods: [8, 10.5, 13.5, 16.5, 26]
    property real a0: 0.3
    property real a1: 2.5
    property real a2: 4.4
    property real a3: 1.4
    property real a4: 3.3
    property real moonAngle: 0

    // Orbits follow a smoothed panel, so they glide when the result list resizes it.
    property real cx: 0
    property real cy: 0
    property real halfWidth: 0
    property real halfHeight: 0

    // The plane as the shader sees it (its RATIO and TILT), its innermost orbit, and
    // its outermost. Its center sits below the panel's by lift, far enough that the
    // near half of every orbit passes below the panel and the far half behind it.
    readonly property real ratio: 0.46
    readonly property real tilt: -0.08
    readonly property real innerOrbit: 1.2
    readonly property real outerOrbit: 2.27
    readonly property real lift: Math.max(0, halfHeight + 12 + halfWidth * Math.abs(Math.sin(tilt))
                                          - ratio * halfWidth * Math.sqrt(innerOrbit * innerOrbit - 1))

    // Fast at the start, easing into place; run backwards it accelerates inward.
    readonly property real eased: 1 - Math.pow(1 - open, 3)
    readonly property real spread: 1 - Math.pow(1 - Math.max(0, (open - 0.12) / 0.88), 3)
    readonly property real scale: halfWidth * (0.12 + 0.88 * spread)
    readonly property point center: Qt.point(cx, cy + lift * spread)
    readonly property real fade: Math.min(1, open * 2)
    readonly property real revealMax: Math.sqrt(panelRect.width * panelRect.width
                                                + panelRect.height * panelRect.height) / 2 + 6
    readonly property bool capturing: open < 1 || !active
    readonly property point origin: Qt.point(panelRect.x + panelRect.width / 2, panelRect.y + panelRect.height / 2)

    // The comet: a parabola round the orbit center, closest below the panel, timed by
    // Barker's equation so it creeps far out and swings fast round the near side.
    // Each pass takes cometCycle; the first starts on its way in, and every other
    // one comes from the other side.
    readonly property real cometCycle: 40
    readonly property real cometPace: 4
    readonly property real cometLead: cometCycle / 2 - 1.3 * cometPace
    property point comet
    property point cometBack
    property real cometDepth: 0
    property real cometNear: 0
    property real cometShow: 0

    onActiveChanged: {
        if (active) {
            flaring = open === 0;
            flare = 0;
            tail = 0;
            exitDone = false;
        }
    }

    function follow(dt) {
        const mx = panelRect.x + panelRect.width / 2;
        const my = panelRect.y + panelRect.height / 2;
        const k = halfWidth === 0 ? 1 : 1 - Math.exp(-dt * 10);
        cx += (mx - cx) * k;
        cy += (my - cy) * k;
        halfWidth += (panelRect.width / 2 - halfWidth) * k;
        halfHeight += (panelRect.height / 2 - halfHeight) * k;
    }

    // Kepler-ish: tighter orbits turn faster, so planets swirl in and out.
    function orbit(dt) {
        const boost = Math.min(10, Math.pow(0.12 + 0.88 * spread, -1.5));
        const w = 2 * Math.PI * dt * boost;
        a0 += w / periods[0];
        a1 += w / periods[1];
        a2 += w / periods[2];
        a3 += w / periods[3];
        a4 += w / periods[4];
        moonAngle += 2 * Math.PI * dt / 3.2;
    }

    // The comet's place in the plane at time t (x across, y toward the viewer, px).
    function cometInPlane(t) {
        const s = t + cometLead;
        const m = ((s % cometCycle) - cometCycle / 2) / cometPace;
        const w = 1.5 * m;
        const y = Math.cbrt(w + Math.sqrt(w * w + 1));
        const d = y - 1 / y;
        const r = 1.5 * scale * (1 + d * d);
        const a = Math.PI / 2 + 0.5 + 2 * Math.atan(d);
        const side = Math.floor(s / cometCycle) % 2 === 0 ? 1 : -1;
        return Qt.point(side * r * Math.cos(a), r * Math.sin(a));
    }

    function onScreen(v) {
        const c = Math.cos(tilt), s = Math.sin(tilt);
        const y = v.y * ratio;
        return Qt.point(center.x + c * v.x - s * y, center.y + s * v.x + c * y);
    }

    function moveComet() {
        const v = cometInPlane(time);
        const was = onScreen(cometInPlane(time - 0.1));
        comet = onScreen(v);
        const bx = was.x - comet.x, by = was.y - comet.y;
        const bl = Math.max(1e-3, Math.hypot(bx, by));
        cometBack = Qt.point(bx / bl, by / bl);
        const r = Math.hypot(v.x, v.y);
        cometDepth = v.y / r;
        cometNear = 1.5 * scale / r;
        const m = Math.abs(((time + cometLead) % cometCycle) - cometCycle / 2) / cometPace;
        cometShow = fade * Math.min(1, time / 2.5) * Math.max(0, Math.min(1, 4.2 - m));
    }

    EffectClock {
        onAdvanced: dt => {
            root.time += dt;
            root.follow(dt);
            root.orbit(dt);
            root.moveComet();
            if (root.active) {
                if (root.flaring) {
                    root.flare = Math.min(1, root.flare + dt / root.flareTime);
                    root.flaring = root.flare < 1;
                } else {
                    root.open = Math.min(1, root.open + dt / root.openTime);
                }
            } else if (root.open > 0) {
                root.open = Math.max(0, root.open - dt / root.closeTime);
            } else if (!root.exitDone) {
                root.tail = Math.min(root.tailTime, root.tail + dt);
                if (root.tail >= root.tailTime) {
                    root.exitDone = true;
                    // Speshell may destroy this item inside the signal, so nothing may follow it.
                    root.closingFinished();
                }
            }
        }
    }

    // ── The orrery ──
    ShaderEffect {
        readonly property real reach: root.outerOrbit * root.halfWidth + 70
        readonly property real depth: root.ratio * reach
        visible: root.halfWidth > 0 && root.open > 0
        x: root.cx - reach
        y: root.cy - Math.max(root.halfHeight + 40, depth - root.lift)
        width: 2 * reach
        height: root.cy + root.lift + depth - y
        property rect rect: Qt.rect(x, y, width, height)
        property rect panel: root.panelRect
        property real radius: root.panelRadius
        property point origin: root.origin
        property real circle: root.eased * root.revealMax
        property point sun: Qt.point(root.cx, root.cy)
        property point center: root.center
        property real scale: root.scale
        property real fade: root.fade
        property real glow: root.eased
        property real time: root.time
        property vector4d angles: Qt.vector4d(root.a0, root.a1, root.a2, root.a3)
        property real angle4: root.a4
        property real moonAngle: root.moonAngle
        property color c0: Colors.mix(root.theme.overlay, root.theme.text, 0.35)
        property color c1: Colors.mix(root.gold, root.theme.text, 0.25)
        property color c2: root.theme.blue
        property color c3: Colors.mix(root.theme.error, root.theme.peach, 0.25)
        property color c4: root.warm
        property color cLand: Colors.mix(root.theme.teal, root.theme.success, 0.5)
        property color cBand: Colors.mix(root.gold, root.theme.text, 0.15)
        property color cRing: Colors.alpha(Colors.mix(root.gold, root.theme.text, 0.35), 0.9)
        property color cMoon: Colors.mix(root.theme.text, root.theme.overlay, 0.3)
        property color cShade: root.theme.mantle
        property color cOrbit: Colors.alpha(root.theme.text, 0.26)
        property color cGlow: Colors.alpha(root.warm, 0.3)
        property color cGlint: root.theme.text
        property color cDust: Colors.mix(root.theme.text, root.gold, 0.3)
        fragmentShader: Qt.resolvedUrl("qsb/LauncherTransition.qsb")
    }

    // ── The comet, on its own small item that rides along with its head ──
    ShaderEffect {
        readonly property real reach: tail * 1.45 + size * 6 + 4
        visible: root.cometShow > 0
        x: root.comet.x - reach
        y: root.comet.y - reach
        width: 2 * reach
        height: 2 * reach
        property rect rect: Qt.rect(x, y, width, height)
        property rect panel: root.panelRect
        property real radius: root.panelRadius
        property point away: {
            const dx = root.comet.x - root.cx, dy = root.comet.y - root.cy;
            const l = Math.max(1e-3, Math.hypot(dx, dy));
            return Qt.point(dx / l, dy / l);
        }
        property point back: root.cometBack
        property real size: 1.7 * (1 + 0.3 * root.cometDepth)
        property real tail: 60 + 80 * Math.min(1, root.cometNear)
        property real k: root.cometShow
        property color cHead: root.hot
        property color cDust: Colors.mix(root.theme.text, root.gold, 0.25)
        property color cIon: root.theme.sky
        fragmentShader: Qt.resolvedUrl("qsb/LauncherTransition.comet.qsb")
    }

    // ── The panel inside the portal; otherwise the real panel shows ──
    ShaderEffectSource {
        id: panelTex
        sourceItem: root.panel
        hideSource: root.capturing
        live: root.capturing
    }

    // Past the panel, so the ring tapers off beyond its edge rather than being cut.
    ShaderEffect {
        readonly property real margin: 28
        visible: root.capturing && root.panel !== null
        x: root.panelRect.x - margin
        y: root.panelRect.y - margin
        width: root.panelRect.width + 2 * margin
        height: root.panelRect.height + 2 * margin
        property var source: panelTex
        property rect rect: Qt.rect(x, y, width, height)
        property rect panel: root.panelRect
        property real radius: root.panelRadius
        property point origin: root.origin
        property real circle: root.eased * root.revealMax
        property real outside: 0
        property real lens: 14 * (1 - root.eased)
        property real ringWidth: 1
        property real ring: root.open > 0 && root.open < 1 ? 1 : 0
        property real debris: 0
        property color cHot: root.hot
        property color cGlow: root.warm
        property color cHaze: root.violet
        fragmentShader: Qt.resolvedUrl("qsb/Portal.qsb")
    }

    // ── The star the panel opens from and collapses into ──
    Glint {
        cx: root.origin.x
        cy: root.origin.y
        size: 200
        spin: 0.2 + root.open * 0.8
        cHot: root.hot
        cGlow: root.gold
        k: {
            if (root.active)
                return root.flaring ? root.flare : Math.max(0, 1 - root.open * 2.5);
            if (root.open > 0)
                return Math.max(0, (0.35 - root.open) / 0.35);
            return 1 - root.tail / root.tailTime;
        }
    }
}
