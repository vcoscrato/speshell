import QtQuick
import qs.services

// The ring around a control while the keyboard is on it. Declare it last inside the
// control, which takes focus with `activeFocusOnTab`; Speshell's controls take focus
// only from Tab, never from a click, so the ring shows only for the keyboard.
Rectangle {
    id: root

    // The control it marks, when that isn't the ring's parent, as a slider's handle.
    property Item control: parent

    anchors.fill: parent
    visible: root.control !== null && root.control.activeFocus
    radius: Theme.borderRadius
    color: "transparent"
    border.width: Theme.outlineWidth
    border.color: Theme.focusRing

    // A hairline in the surface's color inside it, so it reads on an accent fill too.
    Rectangle {
        anchors.fill: parent
        anchors.margins: root.border.width
        radius: Math.max(0, root.radius - root.border.width)
        color: "transparent"
        border.width: Theme.borderWidth
        border.color: Theme.bg
    }
}
