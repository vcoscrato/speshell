import QtQuick
import qs.services

// An icon on a round, tinted disc, leading a row or an empty state: in its tone while
// `lit`, quiet otherwise. `spinning` turns the icon while something is busy.
Rectangle {
    id: root

    property string iconName: ""
    property color toneColor: Theme.accent
    property bool lit: false
    property bool spinning: false
    property real size: Theme.controlHeight

    width: root.size
    height: root.size
    radius: root.size / 2
    color: Theme.alpha(root.lit ? root.toneColor : Theme.overlay, root.lit ? Theme.tintStrong : Theme.tintSubtle)

    Behavior on color {
        ColorAnimation { duration: Theme.animDurationFast }
    }

    AppIcon {
        anchors.centerIn: parent
        name: root.iconName
        size: root.size >= Theme.controlHeight * 1.5 ? Theme.iconSizeLarge : Theme.iconSizeMedium
        iconColor: root.lit || root.spinning ? root.toneColor : Theme.subtextBright
        spinning: root.spinning
    }
}
