import QtQuick
import "Stone.js" as Stone
import "common"

// Earth wallpaper transition: cracks race out from the middle of the screen, then
// the old wallpaper crumbles away shard by shard from the middle outward.
Item {
    id: root

    // ── Speshell effects API v1 ────────────────────────────────
    property Item outgoing: null
    // The active palette, as Theme.qml names it.
    property var theme: null
    signal finished()

    readonly property real crackTime: 0.35
    readonly property real crumbleTime: 1.3

    property real elapsed: 0
    property bool done: false
    readonly property point center: Qt.point(width * 0.5, height * 0.55)
    readonly property real reach: Math.sqrt(Math.pow(width * 0.5, 2) + Math.pow(height * 0.55, 2)) + 120

    EffectClock {
        onAdvanced: function(dt) {
            root.elapsed += dt;
            if (!root.done && root.elapsed >= root.crackTime + root.crumbleTime) {
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

    ShaderEffect {
        anchors.fill: parent
        property var source: outgoingTex
        property size resolution: Qt.size(width, height)
        property point center: root.center
        property real crackR: Math.min(1, root.elapsed / root.crackTime) * root.reach
        // The last shards need 260 px of wave past them to finish falling.
        property real wave: Math.max(0, root.elapsed - root.crackTime * 0.6) / root.crumbleTime * (root.reach + 320)
        property color cCrack: Stone.tone(root.theme, "crust", 0.15, "#2a2219")
        property color cLip: Stone.tone(root.theme, "text", 0.35, "#d8c8a8")
        fragmentShader: Qt.resolvedUrl("qsb/WallpaperTransition.qsb")
    }
}
