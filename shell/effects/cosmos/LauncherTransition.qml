import QtQuick
import "common"
import "common/Colors.js" as Colors

// Cosmos launcher transition: a star flares where the panel will be, and the panel
// opens out of it behind a bright ring while planets spiral out to their orbits.
// While open, a small solar system circles the panel, which plays the sun. Closing
// collapses the panel back into the star, the planets falling in after it.
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
    readonly property real flareTime: 0.16
    readonly property real openTime: 0.6
    readonly property real closeTime: 0.42
    readonly property real tailTime: 0.24      // the star fading after the panel is gone

    // ── Palette, from the theme; Gruvbox until it arrives ─────────
    // The star's white-hot core, brighter than any theme color.
    readonly property color hot: root.theme ? Qt.lighter(Colors.mix(root.theme.text, root.theme.yellow, 0.15), 1.2) : "#fbf1c7"
    readonly property color warm: root.theme ? root.theme.accent : "#fe8019"
    readonly property color gold: root.theme ? root.theme.yellow : "#fabd2f"
    readonly property color violet: root.theme ? root.theme.pink : "#d3869b"

    // 0..1 entrance progress; the exit runs it backwards, so a reopen mid-exit
    // simply turns around.
    property real open: 0
    property real flare: 0
    property bool flaring: true
    property real tail: 0
    property bool exitDone: false

    // Orbit periods (seconds) and angles of the five planets, and the moon's.
    readonly property var periods: [5.5, 8.5, 12, 16, 24]
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

    // Fast at the start, easing into place; run backwards it accelerates inward.
    readonly property real eased: 1 - Math.pow(1 - open, 3)
    readonly property real spread: 1 - Math.pow(1 - Math.max(0, (open - 0.12) / 0.88), 3)
    readonly property real revealMax: Math.sqrt(panelRect.width * panelRect.width
                                                + panelRect.height * panelRect.height) / 2 + 6
    readonly property bool capturing: open < 1 || !active
    readonly property point origin: Qt.point(panelRect.x + panelRect.width / 2, panelRect.y + panelRect.height / 2)
    readonly property real outerOrbit: halfWidth * 2.02

    onActiveChanged: {
        if (active) {
            flaring = open === 0;
            flare = 0;
            tail = 0;
            exitDone = false;
        }
    }

    function follow(dt) {
        var mx = panelRect.x + panelRect.width / 2;
        var my = panelRect.y + panelRect.height / 2;
        var k = halfWidth === 0 ? 1 : 1 - Math.exp(-dt * 10);
        cx += (mx - cx) * k;
        cy += (my - cy) * k;
        halfWidth += (panelRect.width / 2 - halfWidth) * k;
    }

    // Kepler-ish: tighter orbits turn faster, so planets swirl in and out.
    function orbit(dt) {
        var boost = Math.min(10, Math.pow(0.12 + 0.88 * spread, -1.5));
        var w = 2 * Math.PI * dt * boost;
        a0 += w / periods[0];
        a1 += w / periods[1];
        a2 += w / periods[2];
        a3 += w / periods[3];
        a4 += w / periods[4];
        moonAngle += 2 * Math.PI * dt / 2.2;
    }

    EffectClock {
        onAdvanced: function(dt) {
            root.follow(dt);
            root.orbit(dt);
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

    // ── The solar system ──
    ShaderEffect {
        readonly property real reach: root.outerOrbit + 40
        visible: root.halfWidth > 0 && (root.open > 0 || root.flaring)
        x: root.cx - reach
        y: root.cy - Math.max(reach * 0.58, root.panelRect.height / 2 + 80)
        width: 2 * reach
        height: 2 * (root.cy - y)
        property rect rect: Qt.rect(x, y, width, height)
        property rect panel: root.panelRect
        property real radius: 10
        property point origin: root.origin
        property real circle: root.eased * root.revealMax
        property point center: Qt.point(root.cx, root.cy)
        property real halfWidth: root.halfWidth
        property real spread: root.spread
        property real fade: Math.min(1, root.open * 2)
        property real glow: root.eased
        property vector4d angles: Qt.vector4d(root.a0, root.a1, root.a2, root.a3)
        property real angle4: root.a4
        property real moonAngle: root.moonAngle
        property color c0: root.theme ? Colors.mix(root.theme.overlay, root.theme.text, 0.4) : "#a89984"
        property color c1: root.gold
        property color c2: root.theme ? root.theme.blue : "#83a598"
        property color c3: root.theme ? root.theme.error : "#fb4934"
        property color c4: root.warm
        property color cRing: Colors.alpha(Colors.mix(root.gold, root.hot, 0.5), 0.85)
        property color cMoon: root.theme ? root.theme.text : "#ebdbb2"
        property color cShade: root.theme ? root.theme.mantle : "#1d2021"
        property color cOrbit: root.theme ? Colors.alpha(root.theme.text, 0.34) : Qt.rgba(0.92, 0.86, 0.70, 0.34)
        property color cGlow: Colors.alpha(root.warm, 0.3)
        property color cGlint: root.theme ? root.theme.text : "#ebdbb2"
        fragmentShader: Qt.resolvedUrl("qsb/LauncherTransition.qsb")
    }

    // ── The panel inside the portal; otherwise the real panel shows ──
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
