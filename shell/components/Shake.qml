import QtQuick
import qs.services

// A no, as for a wrong password: `offset`, the Translate of what shakes, side to side.
SequentialAnimation {
    id: root

    required property Translate offset

    // Plays, unless the interface keeps still.
    function play() {
        if (Theme.motion)
            root.restart();
    }

    // Each swing shorter than the last.
    NumberAnimation { target: root.offset; property: "x"; to: -Theme.shakeDistance; duration: Theme.shakeDuration * 0.2 }
    NumberAnimation { target: root.offset; property: "x"; to: Theme.shakeDistance * 0.8; duration: Theme.shakeDuration * 0.3 }
    NumberAnimation { target: root.offset; property: "x"; to: -Theme.shakeDistance * 0.5; duration: Theme.shakeDuration * 0.27 }
    NumberAnimation { target: root.offset; property: "x"; to: 0; duration: Theme.shakeDuration * 0.23 }
}
