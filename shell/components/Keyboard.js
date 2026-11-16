.pragma library

// Whether a key press presses the focused control, as a click would: Space, Return, or
// Enter, once however long it's held.
function presses(event) {
    return !event.isAutoRepeat
        && (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter);
}

// The step an arrow key takes along a row or a slider, 1 toward the end, -1 toward the
// start, or 0 for any other key.
function arrowStep(event) {
    if (event.key === Qt.Key_Right || event.key === Qt.Key_Up)
        return 1;
    if (event.key === Qt.Key_Left || event.key === Qt.Key_Down)
        return -1;
    return 0;
}
