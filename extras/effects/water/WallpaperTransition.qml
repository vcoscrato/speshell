import QtQuick
import "common"
import "common/Colors.js" as Colors

// Water wallpaper transition: a drop lands in the middle of the screen and its
// ripple spreads out, carrying the new wallpaper in behind it.
Item {
    id: root

    // ── Speshell effects API v1 ────────────────────────────────
    property Item outgoing: null
    // The active palette, as Theme.qml names it.
    property var theme: null
    property Item incoming: null
    signal finished()

    readonly property real spreadTime: 1.5
    readonly property real calmTime: 0.6

    property real sweep: 0
    property real calm: 0
    property bool done: false
    readonly property point center: Qt.point(width * 0.5, height * 0.55)
    readonly property real reach: Math.sqrt(Math.pow(width * 0.5, 2) + Math.pow(height * 0.55, 2)) + 120

    EffectClock {
        onAdvanced: function(dt) {
            if (root.sweep < 1) {
                root.sweep = Math.min(1, root.sweep + dt / root.spreadTime);
            } else if (root.calm < 1) {
                root.calm = Math.min(1, root.calm + dt / root.calmTime);
            } else if (!root.done) {
                root.done = true;
                // Speshell may destroy this item inside the signal, so nothing may follow it.
                root.finished();
            }
        }
    }

    ShaderEffectSource {
        id: outgoingTex
        sourceItem: root.outgoing
        hideSource: true
        live: false
    }

    ShaderEffectSource {
        id: incomingTex
        sourceItem: root.incoming
        hideSource: true
        live: false
    }

    ShaderEffect {
        anchors.fill: parent
        property var outgoingTex: outgoingTex
        property var incomingTex: incomingTex
        property size resolution: Qt.size(width, height)
        property point center: root.center
        // Ripples slow as they spread.
        property real ring: (1 - Math.pow(1 - root.sweep, 1.6)) * root.reach
        property real strength: 16 * (1 - 0.5 * root.sweep)
        property real calm: Math.max(root.calm, root.sweep > 0.85 ? (root.sweep - 0.85) / 0.6 : 0)
        property color cLight: root.theme ? root.theme.text : "#e8f6fd"
        property color cDark: root.theme ? Colors.mix(root.theme.crust, root.theme.accent, 0.3) : "#123a55"
        fragmentShader: Qt.resolvedUrl("qsb/WallpaperTransition.qsb")
    }
}
