import QtQuick
import qs.services

// A text field: an optional icon before the text, a placeholder, and with `confirmText`,
// a button beside it that confirms (Connect, Save). Enter accepts. Escape clears a
// `clearable` field, then lets an empty one's Escape through; other fields it cancels.
// With `autoFocus`, it takes the keyboard as it shows; it forgets what was typed when
// hidden. `compact` fits a row of tabs, and `large` leads a window, as the launcher's.
// keyPressed() sees each key first, and takes it by accepting it.
Item {
    id: root

    property alias text: input.text
    property alias cursorPosition: input.cursorPosition
    property alias maximumLength: input.maximumLength
    readonly property alias contentWidth: input.contentWidth
    readonly property alias inputFocused: input.activeFocus
    property string placeholder: ""
    property string iconName: ""
    property bool masked: false
    property bool clearable: false
    property string confirmText: ""
    property bool autoFocus: false
    property bool compact: false
    property bool large: false
    readonly property int padding: root.large ? Theme.spacingMedium : Theme.spacingSmall

    signal accepted()
    signal cancelled()
    // The text changed by typing, not by a binding.
    signal edited()
    signal keyPressed(var event)

    function focusInput() {
        input.forceActiveFocus();
    }

    width: parent ? parent.width : 300
    height: root.large ? Math.max(48, Math.ceil(Theme.fontSizeLarge * 1.35) + Theme.spacingMedium * 2)
        : root.compact ? Theme.controlHeightSmall
        : Theme.controlHeight

    onVisibleChanged: {
        if (visible && root.autoFocus)
            root.focusInput();
        else if (!visible)
            input.text = "";
    }

    Rectangle {
        id: box
        anchors.left: parent.left
        anchors.right: confirmButton.visible ? confirmButton.left : parent.right
        anchors.rightMargin: confirmButton.visible ? Theme.spacingSmall : 0
        height: parent.height
        radius: Theme.borderRadius
        color: Theme.controlFill
        border.width: Theme.borderWidth
        border.color: input.activeFocus ? Theme.accent : Theme.controlBorder

        AppIcon {
            id: icon
            anchors.left: parent.left
            anchors.leftMargin: root.padding
            anchors.verticalCenter: parent.verticalCenter
            visible: root.iconName !== ""
            name: root.iconName
            size: root.large ? Theme.iconSizeMedium : Theme.iconSizeSmall
            iconColor: input.activeFocus ? Theme.accent : Theme.subtext
        }

        TextInput {
            id: input
            anchors.left: icon.visible ? icon.right : parent.left
            anchors.right: clearButton.visible ? clearButton.left : parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: root.padding
            anchors.rightMargin: root.padding
            echoMode: root.masked ? TextInput.Password : TextInput.Normal
            selectByMouse: true
            color: Theme.text
            selectionColor: Theme.accent
            selectedTextColor: Theme.onAccent
            font.pixelSize: root.large ? Theme.fontSizeLarge : Theme.fontSizeSmall
            font.family: Theme.fontFamily
            clip: true
            Accessible.name: root.placeholder
            onAccepted: root.accepted()
            onTextEdited: root.edited()
            Keys.onPressed: event => root.keyPressed(event)
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

            // The placeholder, in the field's font, a size down in a large field.
            Label {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: root.placeholder
                color: Theme.overlay
                font.pixelSize: root.large ? Theme.fontSizeNormal : input.font.pixelSize
                elide: Text.ElideRight
                visible: input.text === "" && !input.preeditText
            }
        }

        IconButton {
            id: clearButton
            anchors.right: parent.right
            anchors.rightMargin: Theme.spacingTiny
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
    }

    ActionButton {
        id: confirmButton
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: root.confirmText !== ""
        text: root.confirmText
        kind: "primary"
        onClicked: root.accepted()
    }
}
