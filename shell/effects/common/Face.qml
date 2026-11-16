import QtQuick
import "Colors.js" as Colors

// A clock face drawn by one shader: the API, and the time as the uniforms a face's
// shader reads, with its colors and `fragmentShader` set by the face. `area` is its
// size; `hourTurn`, `minuteTurn`, and `secondTurn` each hand's turns from twelve (see
// ClockTime); `ticking` 1 while the second hand runs; `sinceTick` the time since it
// last ticked; and `time` the ambient time.
ShaderEffect {
    id: root

    // ── Speshell effects API v1: clock ──────────────────────
    property var theme: Colors.fallback
    property int hours: 0
    property int minutes: 0
    property int seconds: 0
    property bool running: true

    property size area: Qt.size(width, height)
    property real hourTurn: clockTime.hourTurn
    property real minuteTurn: clockTime.minuteTurn
    property real secondTurn: clockTime.secondTurn
    property real ticking: root.running ? 1 : 0
    property real sinceTick: clockTime.sinceTick
    property real time: clockTime.clock

    ClockTime {
        id: clockTime
        hours: root.hours
        minutes: root.minutes
        seconds: root.seconds
        running: root.running
    }
}
