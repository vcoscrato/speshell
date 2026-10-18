import QtQuick
import Quickshell.Services.UPower
import qs.components
import qs.theme

// The laptop battery's charge, whether it charges, and the time to full or empty.
Card {
    id: root

    readonly property var battery: UPower.displayDevice
    readonly property bool ready: root.battery !== null && root.battery.ready
    readonly property real percent: root.ready ? root.battery.percentage * 100 : 0
    readonly property bool charging: root.ready && (root.battery.state === UPowerDeviceState.Charging
        || root.battery.state === UPowerDeviceState.PendingCharge)
    readonly property bool full: root.ready && root.battery.state === UPowerDeviceState.FullyCharged
    readonly property color tone: root.charging || root.full
        ? Theme.success
        : (root.percent <= 10 ? Theme.error : (root.percent <= 25 ? Theme.warning : Theme.accent))

    title: "Battery"
    iconName: "battery"

    // "2 h 5 min", or "" when unknown.
    function duration(seconds) {
        if (!seconds || seconds <= 0)
            return "";
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor(seconds % 3600 / 60);
        return hours > 0 ? hours + " h " + minutes + " min" : minutes + " min";
    }

    readonly property string detail: {
        if (!root.ready)
            return "";
        if (root.full)
            return "Fully charged";
        if (root.charging) {
            const toFull = root.duration(root.battery.timeToFull);
            return toFull !== "" ? "Charging · full in " + toFull : "Charging";
        }
        const toEmpty = root.duration(root.battery.timeToEmpty);
        return toEmpty !== "" ? toEmpty + " left" : "On battery";
    }

    Item {
        width: parent.width
        height: Math.max(percentText.implicitHeight, gauge.height)

        Text {
            id: percentText
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.ready ? Math.round(root.percent) + "%" : "—"
            font.pixelSize: Theme.fontSizeTitle
            font.family: Theme.fontFamily
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
            color: Theme.text
        }

        Text {
            anchors.left: percentText.right
            anchors.leftMargin: Theme.spacingMedium
            anchors.right: gauge.left
            anchors.rightMargin: Theme.spacingMedium
            anchors.verticalCenter: parent.verticalCenter
            text: root.detail
            elide: Text.ElideRight
            font.pixelSize: Theme.fontSizeSmall
            font.family: Theme.fontFamily
            color: Theme.subtext
        }

        // The charge as a battery: a frame, the level, and the terminal.
        Item {
            id: gauge
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 64
            height: 22

            Rectangle {
                id: frame
                width: parent.width - 4
                height: parent.height
                radius: Theme.borderRadius
                color: Theme.controlFill
                border.width: Theme.borderWidth
                border.color: Theme.overlay

                Rectangle {
                    x: 3
                    y: 3
                    width: (frame.width - 6) * Math.max(0, Math.min(1, root.percent / 100))
                    height: frame.height - 6
                    radius: Theme.borderRadiusSmall
                    color: root.tone

                    Behavior on width {
                        NumberAnimation { duration: Theme.animDurationSlow; easing.type: Theme.animEasing }
                    }
                }
            }

            Rectangle {
                anchors.left: frame.right
                anchors.leftMargin: 1
                anchors.verticalCenter: parent.verticalCenter
                width: 3
                height: 8
                radius: 1
                color: Theme.overlay
            }
        }
    }
}
