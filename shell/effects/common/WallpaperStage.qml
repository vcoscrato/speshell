import QtQuick
import "Colors.js" as Colors

// A wallpaper transition's API, its clock, and the old wallpaper captured once, as it
// starts. It emits finished() once its clock has run `duration` seconds. advanced(dt)
// follows each step before that, for the transition's own.
Item {
    id: root

    // ── Speshell effects API v1: wallpaper transition ─────────
    property Item outgoing: null
    property Item incoming: null
    // The active palette, as Theme.qml names it.
    property var theme: Colors.fallback
    signal finished()

    property real duration: 1
    property bool done: false

    readonly property EffectClock clock: effectClock
    readonly property ShaderEffectSource outgoingTexture: outgoingTex

    // Emitted after each step but the last, with the time it took.
    signal advanced(real dt)

    EffectClock {
        id: effectClock
        onAdvanced: dt => {
            if (root.done)
                return;
            if (effectClock.clock >= root.duration) {
                root.done = true;
                // Speshell may destroy this item inside the signal, so nothing may follow it.
                root.finished();
                return;
            }
            root.advanced(dt);
        }
    }

    ShaderEffectSource {
        id: outgoingTex
        sourceItem: root.outgoing
        hideSource: true
        live: false
    }
}
