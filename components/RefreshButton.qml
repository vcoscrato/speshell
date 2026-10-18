import QtQuick
import qs.theme

IconButton {

    property bool active: false
    size: Theme.controlHeightSmall
    iconName: active ? "loader" : "refresh"
    iconSize: Theme.iconSizeSmall
    iconColor: active ? Theme.accent : Theme.subtext
    iconSpinning: active
}
