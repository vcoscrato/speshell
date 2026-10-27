pragma ComponentBehavior: Bound
import QtQuick
import qs.components
import qs.services

// The laptop battery's charge, whether it charges, and the time to full or empty; its
// power draw and health; the power mode; and the charge of other devices.
Card {
    id: root

    readonly property color tone: Theme.toneColor(BatteryService.tone)

    readonly property var modeOptions: [
        { value: "saver", label: "Saver" },
        { value: "balanced", label: "Balanced" },
        { value: "maximum", label: "Maximum" }
    ]

    title: "Battery"
    iconName: "battery"

    Item {
        width: parent.width
        height: Math.max(percentText.implicitHeight, gauge.height)

        Label {
            id: percentText
            role: "display"
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: BatteryService.ready ? Math.round(BatteryService.percent) + "%" : "—"
            font.features: { "tnum": 1 }
        }

        Label {
            anchors.left: percentText.right
            anchors.leftMargin: Theme.spacingMedium
            anchors.right: gauge.left
            anchors.rightMargin: Theme.spacingMedium
            anchors.verticalCenter: parent.verticalCenter
            text: BatteryService.detail
            elide: Text.ElideRight
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
                    width: (frame.width - 6) * Math.max(0, Math.min(1, BatteryService.percent / 100))
                    height: frame.height - 6
                    radius: Theme.borderRadius
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

    // Watts in or out, and the capacity left of the battery's design.
    Row {
        visible: BatteryService.watts > 0 || BatteryService.health >= 0
        spacing: Theme.spacingLarge

        Row {
            visible: BatteryService.watts > 0
            spacing: Theme.spacingTiny

            AppIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "plug"
                size: Theme.iconSizeSmall
                iconColor: Theme.subtext
            }

            Label {
                anchors.verticalCenter: parent.verticalCenter
                role: "caption"
                text: (BatteryService.charging ? "Charging at " : "Using ") + BatteryService.watts.toFixed(1) + " W"
                color: Theme.subtext
            }
        }

        Row {
            visible: BatteryService.health >= 0
            spacing: Theme.spacingTiny

            AppIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "battery-health"
                size: Theme.iconSizeSmall
                iconColor: BatteryService.health < 50 ? Theme.warning : Theme.subtext
            }

            Label {
                anchors.verticalCenter: parent.verticalCenter
                role: "caption"
                text: "Health " + Math.round(BatteryService.health) + "%"
                color: BatteryService.health < 50 ? Theme.warning : Theme.subtext
            }
        }
    }

    SettingRow {
        label: "Power mode"
        info: (PowerService.profilesAvailable
                ? "Sets the system's power profile and Speshell's animations together."
                : "Sets how much Speshell animates.")
            + (PowerService.onSaver ? " Picked now, it lasts until plugged in." : "")

        SegmentedControl {
            options: root.modeOptions
            currentValue: PowerService.mode
            onValueSelected: value => PowerService.setMode(value)
        }
    }

    SettingRow {
        label: "Saver on battery"
        info: "Switches to Saver when unplugged, and back to the mode picked while plugged in."

        ToggleSwitch {
            checked: PowerService.saverOnBattery
            tooltipText: "Saver on battery"
            onToggled: on => ConfigService.setProperty("Power", "saverOnBattery", on ? "true" : "false")
        }
    }

    DeviceSection {
        visible: BatteryService.peripherals.length > 0
        title: "Devices"
        count: BatteryService.peripherals.length
    }

    Repeater {
        model: BatteryService.peripherals

        delegate: DeviceRow {
            required property var modelData

            title: modelData.name
            subtitle: modelData.percent + "%"
            subtitleColor: modelData.percent <= BatteryService.lowLevel ? Theme.warning : Theme.subtext
            iconName: modelData.iconName
            primaryEnabled: false
        }
    }
}
