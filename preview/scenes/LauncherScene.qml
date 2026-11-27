import QtQuick
import Quickshell

// Mimics Speshell's launcher host: a mock panel, plus the effects' transition bound the
// same way LauncherOverlay binds it. Opens at t=0, closes at CLOSE_AT seconds, and
// reopens at REOPEN_AT seconds when set.
EffectScene {
    id: root
    // Transition speed, as Speshell's transition host passes it to EffectClock.
    readonly property real timeScale: Number(Quickshell.env("SPEED") || 1)
    readonly property real closeAt: Number(Quickshell.env("CLOSE_AT") || 2.2)
    readonly property real reopenAt: Number(Quickshell.env("REOPEN_AT") || 1e9)
    readonly property bool opened: previewTime < closeAt || previewTime >= reopenAt

    Image {
        anchors.fill: parent
        source: "file://" + Quickshell.env("WALL_A")
        fillMode: Image.PreserveAspectCrop
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.3)
        opacity: root.opened ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
    }

    MockLauncher {
        id: panel
        x: 690
        y: 330
        width: 540
        height: 330
        theme: root.swatch
        // Gone with the launcher, as LauncherOverlay hides its window once the exit finishes.
        visible: root.opened || root.presenting
    }

    // Like Speshell, destroy the transition as soon as it reports the exit finished,
    // and make a new one when it opens again.
    property bool presenting: true
    onOpenedChanged: if (opened) presenting = true

    Loader {
        id: transition
        z: 2
        anchors.fill: parent
        active: root.presenting
        sourceComponent: root.effects ? root.effects.launcherTransition : null
    }

    Binding { target: transition.item; property: "panel"; value: panel }
    Binding { target: transition.item; property: "panelRect"; value: Qt.rect(panel.x, panel.y, panel.width, panel.height) }
    Binding { target: transition.item; property: "panelRadius"; value: panel.radius; when: transition.item !== null && "panelRadius" in transition.item }
    Binding { target: transition.item; property: "active"; value: root.opened }
    Binding { target: transition.item; property: "theme"; value: root.swatch }

    Connections {
        target: transition.item
        ignoreUnknownSignals: true
        function onClosingFinished() {
            console.log("closingFinished at", root.previewTime.toFixed(2));
            root.presenting = false;
        }
    }
}
