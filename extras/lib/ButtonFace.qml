import QtQuick

// A primary button's face, for an effect's Button.qml to give a shader and colors. It
// takes the button API's properties and hands the shader `area` (px), `glow` (0..1,
// easing in on hover), `press` (0..1, while pressed), `at` (the pointer, px), and
// `time`, which moves only while the button is hovered or pressed and holds where it
// stopped, so a face that is still at rest picks up where it left off.
ShaderEffect {
    id: root

    // ── Speshell effects API v1: button ──────────────────────
    property var theme: null
    property bool hovered: false
    property bool pressed: false
    property point pointer: Qt.point(0, 0)
    property bool running: true

    property size area: Qt.size(root.width, root.height)
    property real glow: root.hovered ? 1 : 0
    property real press: root.pressed ? 1 : 0
    property point at: root.pointer
    property real time: 0

    Behavior on glow { NumberAnimation { duration: root.running ? 220 : 0; easing.type: Easing.OutCubic } }
    Behavior on press { NumberAnimation { duration: root.running ? 90 : 0 } }

    Loader {
        id: clock
        active: root.running && (root.glow > 0 || root.press > 0)
        sourceComponent: Component { EffectClock {} }
    }

    Connections {
        target: clock.item
        function onAdvanced(dt) { root.time += dt; }
    }
}
