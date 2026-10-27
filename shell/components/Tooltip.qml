import QtQuick
import QtQuick.Templates as T
import qs.services

// Hover text above a control, styled like HoverLabel. Declare it inside the control
// and drive `visible`.
T.ToolTip {
    id: root

    x: parent ? (parent.width - width) / 2 : 0
    y: -height - Theme.spacingTiny
    width: Math.min(implicitWidth, 260)
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
