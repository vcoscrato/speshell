import QtQuick
import qs.theme

// A text field: an optional icon before the text, a placeholder, and with `confirmText`,
// Cancel and a button that confirms (Connect, Save) after it. Enter accepts. Escape
// clears a `clearable` field, then lets an empty one's Escape through; other fields it
// cancels. With `autoFocus`, it takes the keyboard as it shows; it forgets what was
// typed when hidden.
Rectangle {
    id: root

    property alias text: input.text
    property string placeholder: ""
    property string iconName: ""
    property bool masked: false
    property bool clearable: false
    property string confirmText: ""
    property bool autoFocus: false

    signal accepted()
    signal cancelled()
    // The text changed by typing, not by a binding.
    signal edited()

    function focusInput() {
        input.forceActiveFocus();
    }

    width: parent ? parent.width : 300
    height: Theme.controlHeight
    radius: Theme.borderRadius
    color: Theme.controlFill
    border.width: Theme.borderWidth
    border.color: input.activeFocus ? Theme.accent : Theme.controlBorder

    onVisibleChanged: {
        if (visible && root.autoFocus)
            root.focusInput();
        else if (!visible)
            input.text = "";
    }

    AppIcon {
        id: icon
        anchors.left: parent.left
        anchors.leftMargin: Theme.spacingSmall
        anchors.verticalCenter: parent.verticalCenter
        visible: root.iconName !== ""
        name: root.iconName
        size: Theme.iconSizeSmall
        iconColor: input.activeFocus ? Theme.accent : Theme.subtext
    }

    TextInput {
        id: input
        anchors.left: icon.visible ? icon.right : parent.left
        anchors.right: trailing.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Theme.spacingSmall
        anchors.rightMargin: Theme.spacingSmall
        echoMode: root.masked ? TextInput.Password : TextInput.Normal
        color: Theme.text
        selectionColor: Theme.accent
        selectedTextColor: Theme.onAccent
        font.pixelSize: Theme.fontSizeSmall
        font.family: Theme.fontFamily
        clip: true
        Accessible.name: root.placeholder
        onAccepted: root.accepted()
        onTextEdited: root.edited()
        Keys.onEscapePressed: event => {
            if (!root.clearable) {
                root.cancelled();
            } else if (input.text !== "") {
                input.text = "";
                root.edited();
            } else {
                event.accepted = false;
            }
        }

        Component.onCompleted: {
            if (root.visible && root.autoFocus)
                root.focusInput();
        }

        // The placeholder, in the field's font.
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.placeholder
            color: Theme.overlay
            font: input.font
            visible: input.text === "" && !input.preeditText
        }
    }

    Row {
        id: trailing
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingTiny
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingTiny

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.clearable && input.text !== ""
            iconName: "close"
            iconSize: Theme.iconSizeTiny
            size: Theme.controlHeightSmall
            iconColor: Theme.subtext
            tooltipText: "Clear"
            onClicked: {
                input.text = "";
                root.edited();
                root.focusInput();
            }
        }

        ActionButton {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.confirmText !== ""
            text: "Cancel"
            compact: true
            onClicked: root.cancelled()
        }

        ActionButton {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.confirmText !== ""
            text: root.confirmText
            kind: "primary"
            compact: true
            onClicked: root.accepted()
        }
    }
}
