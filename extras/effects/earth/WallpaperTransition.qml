import QtQuick
import "Stone.js" as Stone
import "common"

// Earth wallpaper transition: a blow strikes the old wallpaper just below the
// middle; cracks race out from it and branch, and the shards break loose one by one,
// small rubble first and broad slabs last, dropping away in dust.
Item {
    id: root

    // ── Speshell effects API v1 ────────────────────────────────
    property Item outgoing: null
    // The active palette, as Theme.qml names it.
    property var theme: null
    signal finished()

    // The last shards break loose at about 1.65 s and take up to 0.75 s to fall and settle.
    readonly property real duration: 2.4

    property real elapsed: 0
    property bool done: false
    readonly property point center: Qt.point(width * 0.5, height * 0.56)
    readonly property real reach: Math.sqrt(Math.pow(width * 0.5, 2) + Math.pow(height * 0.56, 2))

    EffectClock {
        onAdvanced: function(dt) {
            root.elapsed += dt;
            if (!root.done && root.elapsed >= root.duration) {
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
        property real time: root.elapsed
        property real reach: root.reach
        property color cCrack: Stone.tone(root.theme, "crust", 0.15, "#2a2219")
        property color cLip: Stone.tone(root.theme, "text", 0.3, "#d8c8a8")
        property color cDust: Stone.tone(root.theme, "subtextBright", 0.3, "#cdbb9a")
        property color cDustShade: Stone.tone(root.theme, "subtext", 0.45, "#9c8a6c")
        fragmentShader: Qt.resolvedUrl("qsb/WallpaperTransition.qsb")
    }
}
