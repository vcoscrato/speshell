import QtQuick
import qs.theme

// An inline field, masked by default, with Cancel and Connect buttons. It takes
// focus when shown and forgets what was typed when hidden.
Rectangle {
    id: root

    property alias text: input.text
    property string placeholder: "Password"
    property bool masked: true
    property bool showActions: true
    property bool autoFocus: true

    signal accepted()
    signal cancelled()

    width: parent ? parent.width : 300
    height: Theme.controlHeight
    radius: Theme.borderRadiusSmall
    color: Theme.card
    border.width: Theme.borderWidth
    border.color: input.activeFocus ? Theme.accent : Theme.cardHover

    onVisibleChanged: {
        if (visible && root.autoFocus)
            root.focusInput();
        else if (!visible)
            input.text = "";
    }

    function focusInput() {
        input.forceActiveFocus();
    }

    TextInput {
        id: input
        anchors.left: parent.left
        anchors.right: promptActions.left
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
        onAccepted: root.accepted()
        Keys.onEscapePressed: root.cancelled()

        Component.onCompleted: {
            if (root.visible && root.autoFocus)
                root.focusInput();
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.placeholder
            color: Theme.overlay
            font: input.font
            visible: input.text === ""
        }
    }

    Row {
        id: promptActions
        visible: root.showActions
        width: root.showActions ? implicitWidth : 0
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingTiny
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingTiny

        ActionButton {
            anchors.verticalCenter: parent.verticalCenter
            text: "Cancel"
            compact: true
            onClicked: root.cancelled()
        }

        ActionButton {
            anchors.verticalCenter: parent.verticalCenter
            text: "Connect"
            kind: "primary"
            compact: true
            onClicked: root.accepted()
        }
    }
}
