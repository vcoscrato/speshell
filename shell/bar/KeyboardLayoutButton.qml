pragma ComponentBehavior: Bound
import QtQuick
import qs.components
import qs.services

// The keyboard's layout in the bar, as "BR", where Hyprland switches between several:
// a click opens a menu of them, and scrolling steps through them. Follows switches
// made elsewhere, as by xkb's own shortcut.
BarButton {
    id: root

    readonly property var layouts: HyprlandService.keyboardLayoutList
    readonly property int active: HyprlandService.keyboardLayoutIndex
    readonly property bool menuOpen: menu.visible

    visible: root.layouts.length > 1
    open: root.menuOpen
    label: "Keyboard: " + HyprlandService.keyboardLayout
    text: root.active >= 0 && root.active < root.layouts.length ? root.layouts[root.active].code : ""
    fontWeight: Font.DemiBold
    onClicked: menu.open()
    onWheeled: delta => {
        if (delta)
            HyprlandService.switchKeyboardLayout((root.active + (delta > 0 ? -1 : 1) + root.layouts.length) % root.layouts.length);
    }

    PopupMenu {
        id: menu
        y: root.labelAbove ? -menu.height - Theme.spacingMedium : root.height + Theme.spacingMedium

        Instantiator {
            model: root.layouts

            delegate: PopupMenuItem {
                required property var modelData
                required property int index

                text: modelData.name
                selectable: true
                selected: index === root.active
                onTriggered: HyprlandService.switchKeyboardLayout(index)
            }

            onObjectAdded: (index, object) => menu.insertItem(index, object)
            onObjectRemoved: (index, object) => menu.removeItem(object)
        }
    }
}
