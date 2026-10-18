import QtQuick
import QtQuick.Templates as T
import qs.theme

// A rule between groups of a PopupMenu.
T.MenuSeparator {
    implicitWidth: implicitContentWidth + leftPadding + rightPadding
    implicitHeight: implicitContentHeight + topPadding + bottomPadding
    horizontalPadding: Theme.spacingSmall
    verticalPadding: Theme.spacingTiny

    contentItem: Rectangle {
        implicitHeight: Theme.separatorThickness
        color: Theme.separator
    }
}
