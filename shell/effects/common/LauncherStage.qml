import QtQuick
import "Colors.js" as Colors

// A launcher transition's API, its clock, the panel's capture, and the timing most
// follow. While `active`, `enter` runs 0..1 over `enterTime`, once a reopen mid-exit has
// run `leave` back to 0; once not, `leave` runs 0..1 over `exitTime`, and when it has,
// `tailTime` later and once nothing is `lingering`, the transition emits closingFinished().
// advanced(dt) follows each step, for the transition's own.
Item {
    id: root

    // ── Speshell effects API v1: launcher transition ──────────
    property Item panel: null
    property rect panelRect
    property real panelRadius: 16
    property bool active: false
    // The active palette, as Theme.qml names it.
    property var theme: Colors.fallback
    signal closingFinished()

    // ── Timing (seconds) ────────────────────────────────────
    property real enterTime: 1
    property real exitTime: 0.5
    property real tailTime: 0
    // Holds the end back past the tail, as while the last particles fall.
    property bool lingering: false

    property real enter: 0
    property real leave: 0
    property real tailStart: 0
    property bool exitDone: false

    readonly property EffectClock clock: effectClock
    // The panel, captured and the real one hidden while `capturing`: by default while it
    // comes and goes.
    property bool capturing: root.enter < 1 || root.leave > 0
    readonly property ShaderEffectSource panelTexture: panelTex

    // Emitted after each step but the last, with the time it took.
    signal advanced(real dt)

    onActiveChanged: root.exitDone = false

    EffectClock {
        id: effectClock
        onAdvanced: dt => {
            if (root.active) {
                if (root.leave > 0)
                    root.leave = Math.max(0, root.leave - dt / root.exitTime);
                else
                    root.enter = Math.min(1, root.enter + dt / root.enterTime);
            } else if (root.leave < 1) {
                root.leave = Math.min(1, root.leave + dt / root.exitTime);
                root.tailStart = effectClock.clock;
            } else if (!root.exitDone && effectClock.clock - root.tailStart >= root.tailTime && !root.lingering) {
                root.exitDone = true;
                // Speshell may destroy this item inside the signal, so nothing may follow it.
                root.closingFinished();
                return;
            }
            root.advanced(dt);
        }
    }

    ShaderEffectSource {
        id: panelTex
        sourceItem: root.panel
        hideSource: root.capturing
        live: root.capturing
    }
}
