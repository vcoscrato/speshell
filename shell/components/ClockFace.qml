pragma ComponentBehavior: Bound
import QtQuick
import qs.services

// A clock face showing the time: the theme effects' own, or a plain dial in the
// theme's colors. It keeps time while `ticking`, each second, or each minute in power
// saver, when the face shows hours and minutes and keeps still.
Item {
    id: root

    property bool ticking: false
    // The face to draw, by default the active theme's; null draws the plain dial.
    property Component face: EffectsService.clock
    property date now: new Date()

    // Next second, or next minute when the face keeps still.
    function schedule() {
        tick.stop();
        if (!root.ticking)
            return;
        root.now = new Date();
        const next = new Date(root.now.getTime());
        next.setMilliseconds(0);
        next.setSeconds(Theme.motion ? next.getSeconds() + 1 : 60);
        tick.interval = Math.max(20, next.getTime() - Date.now());
        tick.start();
    }

    onTickingChanged: root.schedule()
    Component.onCompleted: root.schedule()

    Connections {
        target: Theme

        function onMotionChanged() { root.schedule(); }
    }

    Timer {
        id: tick
        onTriggered: root.schedule()
    }

    Loader {
        id: faceLoader

        // EffectClock runs at this speed and frame rate.
        property real timeScale: 1
        property int frameRate: EffectsService.frameRate

        anchors.centerIn: parent
        width: Math.min(root.width, root.height)
        height: width
        sourceComponent: root.face ?? plainFace
    }

    Binding {
        target: faceLoader.item
        property: "theme"
        value: Theme
        when: faceLoader.item !== null && "theme" in faceLoader.item
    }

    Binding {
        target: faceLoader.item
        property: "hours"
        value: root.now.getHours()
        when: faceLoader.item !== null
    }

    Binding {
        target: faceLoader.item
        property: "minutes"
        value: root.now.getMinutes()
        when: faceLoader.item !== null
    }

    Binding {
        target: faceLoader.item
        property: "seconds"
        value: root.now.getSeconds()
        when: faceLoader.item !== null
    }

    Binding {
        target: faceLoader.item
        property: "running"
        value: Theme.motion
        when: faceLoader.item !== null
    }

    // A plain dial: minute and hour marks, two hands, and a second hand in the accent.
    Component {
        id: plainFace

        Item {
            id: face

            property int hours: 0
            property int minutes: 0
            property int seconds: 0
            property bool running: true

            readonly property real radius: Math.min(width, height) / 2

            Rectangle {
                anchors.fill: parent
                radius: face.radius
                color: Theme.mantle
                border.width: Theme.borderWidth * 2
                border.color: Theme.surface2
            }

            Repeater {
                model: 60

                delegate: Spoke {
                    required property int index
                    readonly property bool hour: index % 5 === 0

                    angle: index * 6
                    from: face.radius * 0.93
                    to: face.radius * (hour ? 0.8 : 0.87)
                    thickness: hour ? 3 : 1.5
                    color: hour ? Theme.subtextBright : Theme.overlay
                }
            }

            Spoke {
                angle: (face.hours % 12 + face.minutes / 60) * 30
                from: face.radius * 0.5
                to: 0
                thickness: 6
                color: Theme.text
            }

            Spoke {
                angle: (face.minutes + face.seconds / 60) * 6
                from: face.radius * 0.74
                to: 0
                thickness: 4
                color: Theme.text
            }

            Spoke {
                visible: face.running
                angle: face.seconds * 6
                from: face.radius * 0.8
                to: -face.radius * 0.18
                thickness: 2
                color: Theme.accent
            }

            Rectangle {
                anchors.centerIn: parent
                width: 10
                height: 10
                radius: 5
                color: face.running ? Theme.accent : Theme.text
                border.width: 2
                border.color: Theme.mantle
            }
        }
    }

    // A rounded bar along the radius `angle` degrees clockwise from twelve, between
    // `from` and `to` px from the center (negative past it). Fills the face it's in.
    component Spoke: Item {
        id: spoke

        property real angle: 0
        property real from: 0
        property real to: 0
        property real thickness: 2
        property color color: Theme.text

        anchors.fill: parent
        rotation: spoke.angle

        Rectangle {
            x: spoke.width / 2 - spoke.thickness / 2
            y: spoke.height / 2 - Math.max(spoke.from, spoke.to)
            width: spoke.thickness
            height: Math.abs(spoke.from - spoke.to)
            radius: spoke.thickness / 2
            antialiasing: true
            color: spoke.color
        }
    }
}
