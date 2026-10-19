import QtQuick
import qs.components
import qs.theme

// A bar item's name, shown below it, or above it on a bottom bar, while the pointer is
// over it: centered on the item, but kept on screen.
Rectangle {
    id: root

    property string text: ""
    property bool above: false

    // Centered under the item, then moved in from the screen's edges. Placed as it
    // shows, since the bar doesn't move under it.
    function place() {
        const centered = (parent.width - root.width) / 2;
        const left = parent.mapToItem(null, centered, 0).x;
        const windowWidth = root.Window.window ? root.Window.window.width : left + root.width;
        const shift = Math.max(Theme.spacingSmall - left,
            Math.min(0, windowWidth - Theme.spacingSmall - (left + root.width)));
        root.x = Math.round(centered + shift);
    }

    onVisibleChanged: if (root.visible) root.place()
    onWidthChanged: if (root.visible) root.place()

    y: root.above ? -root.height - Theme.spacingSmall : parent.height + Theme.spacingSmall
    // Padded as Tooltip is.
    width: labelText.implicitWidth + Theme.spacingSmall * 2
    height: labelText.implicitHeight + Theme.spacingTiny * 2
    radius: Theme.borderRadius
    color: Theme.popupFill
    border.width: Theme.borderWidth
    border.color: Theme.popupBorder
    z: 100

    Label {
        id: labelText

        anchors.centerIn: parent
        text: root.text
    }
}
