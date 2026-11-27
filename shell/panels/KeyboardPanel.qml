pragma ComponentBehavior: Bound
import QtQuick
import qs.components
import qs.services

// The keyboard layouts Hyprland switches between, and which one types.
Card {
    id: root
    panel: "keyboard"

    Column {
        width: parent.width
        spacing: Theme.spacingTiny

        Repeater {
            model: HyprlandService.keyboardLayoutList

            delegate: DeviceRow {
                id: layoutRow
                required property var modelData
                required property int index

                title: layoutRow.modelData.name
                subtitle: layoutRow.modelData.code
                iconName: "keyboard"
                current: layoutRow.index === HyprlandService.keyboardLayoutIndex
                onPrimaryTriggered: HyprlandService.switchKeyboardLayout(layoutRow.index)
            }
        }
    }
}
