pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Templates as T
import qs.services
import qs.theme

// Dropdown button that shows the current option's label ({ value, label }) and opens
// a menu of the rest. Unlisted values show fallbackLabel.
Rectangle {
    id: root

    property var options: []
    property var currentValue: undefined
    property string fallbackLabel: currentValue === undefined || currentValue === null
        ? ""
        : String(currentValue)
    property int maxWidth: 200

    signal valueSelected(var selectedValue)

    readonly property string currentLabel: {
        for (var i = 0; i < root.options.length; i++) {
            if (root.options[i].value === root.currentValue)
                return String(root.options[i].label);
        }
        return root.fallbackLabel;
    }
    readonly property bool hovered: selectMouse.containsMouse && root.enabled

    implicitWidth: Math.min(root.maxWidth,
        valueText.implicitWidth + Theme.iconSizeTiny + Theme.spacingTiny
            + Theme.spacingSmall * 2)
    implicitHeight: Math.max(Theme.controlHeightSmall, valueText.implicitHeight + Theme.spacingTiny * 2)
        + Theme.spacingMicro * 2
    width: implicitWidth
    height: implicitHeight
    radius: Theme.borderRadius
    opacity: root.enabled ? 1.0 : Theme.disabledOpacity
    color: root.hovered || selectMenu.opened ? Theme.cardHover : Theme.controlFill
    border.width: Theme.borderWidth
    border.color: selectMenu.opened ? Theme.selectedBorder : Theme.controlBorder

    Accessible.role: Accessible.ComboBox
    Accessible.name: root.currentLabel
    Accessible.onPressAction: {
        if (root.enabled)
            selectMenu.open();
    }

    Label {
        id: valueText

        anchors.left: parent.left
        anchors.leftMargin: Theme.spacingSmall
        anchors.right: chevron.left
        anchors.rightMargin: Theme.spacingTiny
        anchors.verticalCenter: parent.verticalCenter
        text: root.currentLabel
        font.weight: Font.Bold
        elide: Text.ElideRight
    }

    AppIcon {
        id: chevron

        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingSmall
        anchors.verticalCenter: parent.verticalCenter
        name: "chevron-down"
        size: Theme.iconSizeTiny
        iconColor: root.hovered || selectMenu.opened ? Theme.text : Theme.subtext
        rotation: selectMenu.opened ? 180 : 0

        Behavior on rotation {
            NumberAnimation { duration: Theme.animDuration; easing.type: Theme.animEasing }
        }
    }

    MouseArea {
        id: selectMouse
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: selectMenu.open()
    }

    PopupMenu {
        id: selectMenu

        x: root.width - width
        y: root.height + Theme.spacingTiny
        modal: true
        focus: true
        closePolicy: T.Popup.CloseOnPressOutside | T.Popup.CloseOnEscape

        Instantiator {
            model: root.options

            delegate: PopupMenuItem {
                required property var modelData
                focusPolicy: Qt.ClickFocus

                text: String(modelData.label)
                selectable: true
                selected: modelData.value === root.currentValue
                enabled: root.enabled
                onTriggered: {
                    if (modelData.value !== root.currentValue)
                        EffectsService.picked(root, null);
                    root.valueSelected(modelData.value);
                }
            }

            onObjectAdded: function(index, object) {
                selectMenu.insertItem(index, object);
            }
            onObjectRemoved: function(index, object) {
                selectMenu.removeItem(object);
            }
        }
    }
}
