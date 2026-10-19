import QtQuick
import QtQuick.Templates as T
import qs.theme

// A dropdown or context menu of PopupMenuItem and PopupMenuSeparator. Submenus added
// with insertMenu cascade beside it.
T.Menu {
    id: root

    // As wide as its widest row; menus don't size to their rows on their own.
    implicitWidth: {
        var widest = implicitBackgroundWidth - leftPadding - rightPadding;
        for (var i = 0; i < root.count; i++)
            widest = Math.max(widest, root.itemAt(i).implicitWidth);
        return widest + leftPadding + rightPadding;
    }
    implicitHeight: implicitContentHeight + topPadding + bottomPadding
    margins: Theme.spacingSmall
    padding: Theme.spacingTiny
    overlap: Theme.spacingTiny

    delegate: PopupMenuItem {}

    contentItem: ListView {
        implicitHeight: contentHeight
        model: root.contentModel
        interactive: contentHeight > height
        clip: true
        currentIndex: root.currentIndex

        T.ScrollBar.vertical: StyledScrollBar {}
    }

    background: Rectangle {
        implicitWidth: 160
        radius: Theme.borderRadius
        color: Theme.popupFill
        border.width: Theme.borderWidth
        border.color: Theme.popupBorder
    }

    T.Overlay.modal: Item {}
    T.Overlay.modeless: Item {}
}
