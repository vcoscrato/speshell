import QtQuick

// A clock face's time, as the turns (0..1 from twelve, clockwise) of each hand. The hour
// and minute hands creep with the time; the second hand ticks, easing into each new
// second over a fifth of a second. `clock` is the ambient time anything else on the face
// moves by, and `sinceTick` the time since the last tick, for anything that answers it;
// they and the second hand stand still while not `running`, as in power saver.
Item {
    id: root

    property int hours: 0
    property int minutes: 0
    property int seconds: 0
    property bool running: true

    readonly property real hourTurn: (root.hours % 12 + root.minutes / 60 + root.seconds / 3600) / 12
    readonly property real minuteTurn: (root.minutes + root.seconds / 60) / 60
    readonly property real secondTurn: (root.seconds - 1 + root.tick) / 60
    readonly property real clock: effectClock.item ? effectClock.item.clock : 0
    // Seconds since the second hand last ticked; large when it isn't running.
    readonly property real sinceTick: root.tickedAt < 0 ? 1000 : root.clock - root.tickedAt

    // When the last second began, by `clock`, and how far the hand has moved into it.
    property real tickedAt: -1
    readonly property real tick: {
        const t = root.tickedAt < 0 ? 1 : Math.min(1, (root.clock - root.tickedAt) / 0.2);
        return 1 - Math.pow(1 - t, 3);
    }

    onSecondsChanged: root.tickedAt = root.running ? root.clock : -1
    onRunningChanged: root.tickedAt = -1

    Loader {
        id: effectClock
        active: root.running
        sourceComponent: Component {
            EffectClock {}
        }
    }
}
