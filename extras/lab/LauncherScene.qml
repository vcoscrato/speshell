import QtQuick
import Quickshell

// Mimics Speshell's launcher host: a mock panel, plus the effects' transition bound the
// same way LauncherOverlay binds it. Opens at t=0, closes at CLOSE_AT seconds, and
// reopens at REOPEN_AT seconds when set.
Item {
    id: root
    width: 1920
    height: 1080
    property real labTime: 0
    // Transition speed, as Speshell's transition host passes it to EffectClock.
    readonly property real timeScale: Number(Quickshell.env("SPEED") || 1)
    readonly property real closeAt: Number(Quickshell.env("CLOSE_AT") || 2.2)
    readonly property real reopenAt: Number(Quickshell.env("REOPEN_AT") || 1e9)
    readonly property bool opened: labTime < closeAt || labTime >= reopenAt

    property var effects: {
        const component = Qt.createComponent("file://" + Quickshell.env("EFFECTS_DIR") + "/Effects.qml");
        if (component.status !== Component.Ready) {
            console.error(component.errorString());
            return null;
        }
        return component.createObject(root);
    }

    // Theme.qml's color names, from THEME_INI's [Colors].
    ThemePalette {
        id: swatch
    }

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
        theme: swatch
    }

    // Like Speshell, destroy the transition as soon as it reports the exit finished.
    property bool presenting: true

    Loader {
        id: transition
        z: 2
        anchors.fill: parent
        active: root.presenting
        sourceComponent: root.effects ? root.effects.launcherTransition : null
    }

    Binding { target: transition.item; property: "panel"; value: panel }
    Binding { target: transition.item; property: "panelRect"; value: Qt.rect(panel.x, panel.y, panel.width, panel.height) }
    Binding { target: transition.item; property: "active"; value: root.opened }
    Binding { target: transition.item; property: "theme"; value: swatch }

    Connections {
        target: transition.item
        ignoreUnknownSignals: true
        function onClosingFinished() {
            console.log("closingFinished at", root.labTime.toFixed(2));
            root.presenting = false;
        }
    }
}
