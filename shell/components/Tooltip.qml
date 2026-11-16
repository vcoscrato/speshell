import QtQuick
import QtQuick.Templates as T
import qs.services

// Hover text above a control, or `below` it, as under the items of a bar at the top,
// centered on it but kept on screen. Declare it inside the control and drive `visible`.
T.ToolTip {
    id: root

    property bool below: false

    x: parent ? (parent.width - width) / 2 : 0
    y: root.below ? (parent ? parent.height : 0) + Theme.spacingSmall : -height - Theme.spacingTiny
    // Wrapped at three quarters of a panel.
    width: Math.min(implicitWidth, Theme.panelWidth * 3 / 4)
    implicitWidth: implicitContentWidth + leftPadding + rightPadding
    implicitHeight: implicitContentHeight + topPadding + bottomPadding
    margins: Theme.spacingTiny
    horizontalPadding: Theme.spacingSmall
    verticalPadding: Theme.spacingTiny
    delay: 300
    closePolicy: T.Popup.CloseOnEscape | T.Popup.CloseOnPressOutsideParent | T.Popup.CloseOnReleaseOutsideParent

    contentItem: Label {
        text: root.text
        wrapMode: Text.Wrap
    }

    background: Rectangle {
        radius: Theme.borderRadius
        color: Theme.popupFill
        border.width: Theme.borderWidth
        border.color: Theme.popupBorder
    }
}
