import QtQuick
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
    width: labelText.implicitWidth + Theme.spacingLarge
    height: Math.max(26, labelText.implicitHeight + Theme.spacingSmall)
    radius: Theme.borderRadiusSmall
    color: Theme.surface2
    border.width: Theme.borderWidth
    border.color: Theme.selectedBorder
    z: 100

    Text {
        id: labelText

        anchors.centerIn: parent
        text: root.text
        textFormat: Text.PlainText
        font.pixelSize: Theme.fontSizeSmall
        font.family: Theme.fontFamily
        color: Theme.text
    }
}
