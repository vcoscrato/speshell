import QtQuick
import qs.services

// A transient card's entrance, as the OSD's and the toasts': `card` from a little
// smaller and clear to whole, overshooting a touch.
ParallelAnimation {
    id: root

    required property Item card

    // Starts over from the beginning.
    function play() {
        root.card.opacity = 0;
        root.card.scale = 0.96;
        root.restart();
    }

    NumberAnimation {
        target: root.card
        property: "opacity"
        to: 1
        duration: Theme.animDuration
        easing.type: Theme.animEasing
    }

    NumberAnimation {
        target: root.card
        property: "scale"
        to: 1
        duration: Theme.animDuration
        easing.type: Easing.OutBack
    }
}
