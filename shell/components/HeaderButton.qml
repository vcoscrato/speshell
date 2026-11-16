import QtQuick
import qs.services

// An icon action in a panel's header, like refreshing or clearing. `busy` spins its icon
// in the accent while the action runs. `checked` marks one that turns something on, like
// Wi-Fi or Do Not Disturb, filled in the accent while it's on.
IconButton {
    id: root

    property bool busy: false
    property bool checked: false

    size: Theme.controlHeightSmall
    iconSize: Theme.iconSizeSmall
    iconColor: root.busy || root.checked ? Theme.accent : root.containsMouse ? Theme.text : Theme.subtext
    iconSpinning: root.busy
    color: root.checked ? Theme.selectedFill : root.containsMouse && root.enabled ? root.hoverColor : "transparent"
    border.width: root.checked ? Theme.borderWidth : 0
    border.color: Theme.selectedBorder

    Accessible.checkable: root.checked
    Accessible.checked: root.checked
}
