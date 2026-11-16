import QtQuick

// Scrolling over its item as steps: one per notch of a mouse wheel (120 eighths of a
// degree), however finely a touchpad or a smooth wheel reports it, so a swipe moves a
// few steps rather than one per event. `direction` is 1 scrolling up, -1 down; with
// `sideways`, scrolling right or left also counts where nothing scrolls up or down,
// left as up.
WheelHandler {
    id: root

    property bool sideways: false
    // Scrolled since the last step, toward the next.
    property real pending: 0

    signal stepped(int direction)

    target: null
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    onWheel: event => {
        const delta = event.angleDelta.y !== 0 || !root.sideways ? event.angleDelta.y : event.angleDelta.x;
        if (delta === 0)
            return;
        // Turning back starts over, so it answers at once.
        if (delta > 0 !== root.pending > 0)
            root.pending = 0;
        root.pending += delta;
        while (Math.abs(root.pending) >= 120) {
            const direction = root.pending > 0 ? 1 : -1;
            root.pending -= direction * 120;
            root.stepped(direction);
        }
    }
}
