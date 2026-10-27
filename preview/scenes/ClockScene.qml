import QtQuick
import Quickshell

// Mimics the clock panel in THEME_INI's colors: the effects' clock face over their
// backdrop, at the panel's size and at twice it, ticking from 10:09:30. From 3 s it keeps
// still, as in power saver.
Item {
    id: root
    width: 1920
    height: 1080
    property real previewTime: 0
    // As the clock panel passes them to EffectClock.
    readonly property real timeScale: 1
    readonly property int frameRate: 60

    readonly property int time: 10 * 3600 + 9 * 60 + 30 + Math.floor(root.previewTime)
    readonly property bool running: root.previewTime < 3

    property var effects: {
        const component = Qt.createComponent("file://" + Quickshell.env("EFFECTS_DIR") + "/Effects.qml");
        if (component.status !== Component.Ready) {
            console.error(component.errorString());
            return null;
        }
        return component.createObject(root);
    }
    readonly property Component face: root.effects && ("clock" in root.effects) ? root.effects.clock : null

    ThemePalette {
        id: swatch
    }

    Item {
        x: 16
        y: 16
        width: 708
        height: 448
        clip: true

        Rectangle {
            anchors.fill: parent
            color: swatch.bg
        }

        Loader {
            id: backdrop
            width: parent.width
            height: 1050
            sourceComponent: root.effects && ("backdrop" in root.effects) ? root.effects.backdrop : null
        }

        Binding { target: backdrop.item; property: "theme"; value: swatch }

        Face {
            x: 24
            y: 24
            size: 196
        }

        Face {
            x: 284
            y: 24
            size: 400
        }
    }

    component Face: Loader {
        id: face

        property real size: 196

        width: face.size
        height: face.size
        sourceComponent: root.face

        Binding { target: face.item; property: "theme"; value: swatch }
        Binding { target: face.item; property: "hours"; value: Math.floor(root.time / 3600) % 24 }
        Binding { target: face.item; property: "minutes"; value: Math.floor(root.time / 60) % 60 }
        Binding { target: face.item; property: "seconds"; value: root.time % 60 }
        Binding { target: face.item; property: "running"; value: root.running }
    }

    Component.onCompleted: {
        if (root.face === null)
            console.log("no clock face");
    }
}
