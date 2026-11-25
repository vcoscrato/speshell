import QtQuick
import qs.components
import qs.services

// The gate's password field and the message under it. The field follows `draft`, which
// every screen's gate shares, and reports typing with draftEdited(). It follows the
// authentication's `phase` as LockService and the greeter keep it: "idle" asks for the
// password, "checking" says `checkingText`, and "prompt" asks the question the system
// asked next (`prompt`, as a one-time code), shown as typed when `promptVisible`.
Column {
    id: root

    property string draft: ""
    property string phase: "idle"
    property string prompt: ""
    property bool promptVisible: false
    property string checkingText: "Checking…"
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
    // The field forgets its text while hidden, as on the login screen's other displays.
    onVisibleChanged: {
        if (root.visible && password.text !== root.draft)
            password.text = root.draft;
    }

    Field {
        id: password
        masked: root.phase !== "prompt" || !root.promptVisible
        autoFocus: true
        iconName: "lock"
        placeholder: root.phase === "checking" ? root.checkingText
            : root.phase === "prompt" ? root.prompt || "Answer"
            : "Password"
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
