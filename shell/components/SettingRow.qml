import QtQuick
import qs.services

// One setting: a label, an optional hover explanation, and its control on the right.
// A control too wide to share the row moves below the label and takes the full width.
Item {
    id: root

    property string label: ""
    property string info: ""
    default property alias control: controlSlot.data

    readonly property Item controlItem: controlSlot.children.length > 0 ? controlSlot.children[0] : null
    readonly property real controlNaturalWidth: root.controlItem ? root.controlItem.implicitWidth : 0
    readonly property bool stacked: root.controlNaturalWidth + Theme.spacingMedium > root.width * 0.6

    width: parent ? parent.width : 300
    implicitHeight: root.stacked
        ? labelRow.height + Theme.spacingSmall + controlSlot.height
        : Math.max(Theme.controlHeight, labelRow.height, controlSlot.height)
    height: implicitHeight
    opacity: root.enabled ? 1.0 : Theme.disabledOpacity

    Binding {
        target: root.controlItem
        property: "width"
        value: root.stacked ? root.width : root.controlNaturalWidth
        when: root.controlItem !== null
    }

    Row {
        id: labelRow

        readonly property real available: root.stacked
            ? root.width
            : root.width - controlSlot.width - Theme.spacingMedium

        y: root.stacked ? 0 : (root.height - height) / 2
        spacing: Theme.spacingMicro

        Label {
            width: Math.min(implicitWidth, labelRow.available - (infoTip.visible ? infoTip.width + labelRow.spacing : 0))
            text: root.label
            elide: Text.ElideRight
            anchors.verticalCenter: parent.verticalCenter
        }

        InfoTip {
            id: infoTip
            visible: root.info !== ""
            text: root.info
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Item {
        id: controlSlot

        x: root.stacked ? 0 : root.width - width
        y: root.stacked ? labelRow.height + Theme.spacingSmall : (root.height - height) / 2
        width: root.controlItem ? root.controlItem.width : 0
        height: root.controlItem ? root.controlItem.height : 0
    }
}
