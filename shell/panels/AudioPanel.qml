pragma ComponentBehavior: Bound
import QtQuick
import qs.components
import qs.services

// The speaker (`output`) or the microphone: mute, volume, and the device to use.
Card {
    id: root

    property bool presented: false
    property bool output: true
    readonly property var endpoint: root.output ? AudioService.output : AudioService.input

    panel: root.output ? "audio" : "microphone"

    AudioLevel {
        endpoint: root.endpoint
    }

    Column {
        width: parent.width
        spacing: Theme.spacingTiny

        Repeater {
            model: root.presented ? root.endpoint.devices() : []

            delegate: DeviceRow {
                id: deviceRow
                required property var modelData

                title: deviceRow.modelData.label
                // A renamed device under its hardware name.
                subtitle: deviceRow.modelData.label !== deviceRow.modelData.rawLabel ? deviceRow.modelData.rawLabel : ""
                iconName: "audio-" + root.endpoint.kind
                current: root.endpoint.node === deviceRow.modelData.node
                onPrimaryTriggered: root.endpoint.setDevice(deviceRow.modelData.node)
            }
        }
    }
}
