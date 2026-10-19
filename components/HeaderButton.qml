import QtQuick
import qs.theme

// An icon action in a panel's header, like refreshing or clearing. `busy` spins its icon
// in the accent while the action runs.
IconButton {
    id: root

    property bool busy: false

    size: Theme.controlHeightSmall
    iconSize: Theme.iconSizeSmall
    iconColor: root.busy ? Theme.accent : root.containsMouse ? Theme.text : Theme.subtext
    iconSpinning: root.busy
}
