import QtQuick
import qs.components
import qs.services

// The gate's password field and the message under it. The field follows `draft`, which
// every screen's gate shares, and reports typing with draftEdited().
Column {
    id: root

    property string draft: ""
    property string placeholder: "Password"
    property string message: ""
    property bool messageIsError: false

    signal draftEdited(string text)
    signal accepted()

    width: parent ? parent.width : 0
    spacing: Theme.spacingSmall

    onDraftChanged: {
        if (password.text !== root.draft)
            password.text = root.draft;
    }

    Field {
        id: password
        masked: true
        autoFocus: true
        iconName: "lock"
        placeholder: root.placeholder
        onEdited: root.draftEdited(password.text)
        onAccepted: root.accepted()
        onCancelled: root.draftEdited("")
    }

    Label {
        role: "caption"
        visible: root.message !== ""
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: root.message
        color: root.messageIsError ? Theme.error : Theme.subtext
    }
}
