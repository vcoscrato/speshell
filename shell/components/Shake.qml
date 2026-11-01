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

    NumberAnimation { target: root.offset; property: "x"; to: -12; duration: 50 }
    NumberAnimation { target: root.offset; property: "x"; to: 10; duration: 80 }
    NumberAnimation { target: root.offset; property: "x"; to: -6; duration: 70 }
    NumberAnimation { target: root.offset; property: "x"; to: 0; duration: 60 }
}
