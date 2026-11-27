pragma ComponentBehavior: Bound
// Quickshell's type info marks PanelWindow uncreatable, though QML creates it.
// qmllint disable uncreatable-type
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.components
import qs.services

// Dictation's card on the focused screen, while a dictation runs. It shows the words as
// they're heard, those that settled in full and the rest dimmer. Then it holds the text,
// to fix with a click on it and type into the focused window or copy. It sits under the
// bar's right end (above it, with the bar at the bottom) and can be dragged anywhere, where
// it stays, or back, where it docks. The window spans the screen, so the card moves inside
// it, and takes the pointer only over the card. It takes the keyboard only while its text
// is edited, and while the keys that asked to type are let go, so none of them is still
// down when the typed keys come.
PanelWindow {
    id: root

    readonly property string phase: DictationService.phase
    readonly property bool wanted: root.phase !== "idle" && root.phase !== "typing"
    readonly property bool live: root.phase === "listening" || root.phase === "finishing"
    property bool shown: false
    property var targetScreen: null
    readonly property bool barAtTop: ConfigService.settings.bar.position !== "bottom"
    // Where the card was dragged, as its distance from the right edge and the top, or null
    // where it docks.
    property var spot: null
    readonly property real dockRight: Math.max(Theme.spacingSmall,
        Math.round(root.width * (100 - ConfigService.settings.bar.width) / 200))
    readonly property real dockTop: root.barAtTop ? Theme.spacingSmall : root.height - card.height - Theme.spacingSmall
    // The text is being edited, after a click on it.
    property bool editing: false
    readonly property string statePath: ConfigService.dataDir !== "" ? ConfigService.dataDir + "/dictation.json" : ""

    readonly property string status: root.phase === "listening"
        ? (DictationService.preparing === "downloading"
            ? "Downloading the model · " + Math.round(DictationService.downloadProgress * 100) + "%"
            : DictationService.preparing === "loading" ? "Loading the model" : "Listening")
        : root.phase === "finishing" ? "Transcribing"
        : root.phase === "releasing" ? "Let go of the keys to type"
        : "Ready to type"

    // The words heard so far, the pending ones dimmer.
    readonly property string liveText: {
        const escape = text => text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
        const settled = escape(DictationService.settled);
        const pending = escape(DictationService.pending);
        return settled + (settled !== "" && pending !== "" ? " " : "")
            + (pending !== "" ? "<font color=\"" + Theme.subtext + "\">" + pending + "</font>" : "");
    }

    function present() {
        // Called back while fading out: comes back from as far as it got.
        if (exitAnimation.running) {
            exitAnimation.stop();
            comeBack.restart();
        }
        if (root.shown)
            return;
        root.targetScreen = HyprlandService.focusedScreen();
        root.shown = true;
        entrance.play();
    }

    function dismiss() {
        comeBack.stop();
        if (root.shown)
            exitAnimation.restart();
    }

    // Where the card was let go: docked when that's near its dock, and kept.
    function settle() {
        const right = root.width - card.width - card.x;
        const near = Math.abs(right - root.dockRight) < Theme.spacingXL && Math.abs(card.y - root.dockTop) < Theme.spacingXL;
        root.spot = near ? null : { right: right, top: card.y };
        if (root.statePath !== "")
            stateFile.setText(JSON.stringify(root.spot ?? {}));
    }

    function edit() {
        root.editing = true;
        editor.forceActiveFocus();
    }

    onWantedChanged: root.wanted ? root.present() : root.dismiss()
    onPhaseChanged: {
        if (root.phase !== "ready")
            root.editing = false;
        if (root.phase === "releasing")
            keyCatcher.forceActiveFocus();
    }
    // Made anew each time it maps, so the keys go where they should from the start.
    onWindowConnected: if (root.phase === "releasing") keyCatcher.forceActiveFocus()

    screen: root.targetScreen
    visible: root.shown && root.targetScreen !== null
    color: "transparent"
    // Clear of the bar, which reserves its edge.
    exclusionMode: ExclusionMode.Normal
    mask: Region { item: card }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.phase === "releasing" || root.editing ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None
    WlrLayershell.namespace: "speshell-dictation"

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    // A click elsewhere ends the editing, and gives the keyboard back.
    HyprlandFocusGrab {
        active: root.editing && root.backingWindowVisible && HyprlandService.running
        windows: [root]
        onCleared: root.editing = false
    }

    FileView {
        id: stateFile
        path: root.statePath
        atomicWrites: true
        printErrors: false
        onLoaded: {
            try {
                const spot = JSON.parse(stateFile.text() || "{}");
                root.spot = Number.isFinite(spot.right) && Number.isFinite(spot.top) ? spot : null;
            } catch (stateError) {
                root.spot = null;
            }
        }
    }

    // While the keys that asked to type are let go: each key that comes up says whether
    // others are still down.
    Item {
        id: keyCatcher

        readonly property int modifiers: Qt.ShiftModifier | Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier

        function modifierOf(key) {
            if (key === Qt.Key_Shift)
                return Qt.ShiftModifier;
            if (key === Qt.Key_Control)
                return Qt.ControlModifier;
            if (key === Qt.Key_Alt || key === Qt.Key_AltGr)
                return Qt.AltModifier;
            if ([Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R, Qt.Key_Hyper_L, Qt.Key_Hyper_R].indexOf(key) >= 0)
                return Qt.MetaModifier;
            return 0;
        }

        Keys.onPressed: event => {
            event.accepted = true;
            if (event.key === Qt.Key_Escape)
                DictationService.keepText();
            else
                DictationService.keysDown();
        }
        // A key's own modifier counts as down still as it comes up.
        Keys.onReleased: event => {
            event.accepted = true;
            if (event.isAutoRepeat)
                return;
            if ((event.modifiers & keyCatcher.modifiers & ~keyCatcher.modifierOf(event.key)) === 0)
                DictationService.keysUp();
            else
                DictationService.keysDown();
        }
    }

    FontMetrics {
        id: metrics
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
    }

    Item {
        id: card

        property real shownLevel: DictationService.level

        width: Theme.toastWidth
        height: body.implicitHeight + Theme.panelPadding * 2
        x: Math.max(0, Math.min(root.width - card.width, root.width - card.width - (root.spot ? root.spot.right : root.dockRight)))
        y: Math.max(0, Math.min(root.height - card.height, root.spot ? root.spot.top : root.dockTop))
        transformOrigin: root.barAtTop ? Item.Top : Item.Bottom

        Behavior on shownLevel {
            NumberAnimation { duration: Theme.animDurationFast }
        }

        // Away from the screen's edges, so rounded all round.
        Surface {
            anchors.fill: parent
            backdrop: true
            rounded: true
        }

        // Dragged from anywhere but the text being edited.
        DragHandler {
            id: dragger

            property real startRight: 0
            property real startTop: 0

            target: null
            enabled: !editor.activeFocus
            onActiveChanged: {
                if (active) {
                    dragger.startRight = root.width - card.width - card.x;
                    dragger.startTop = card.y;
                } else {
                    root.settle();
                }
            }
            onTranslationChanged: {
                if (active)
                    root.spot = { right: dragger.startRight - translation.x, top: dragger.startTop + translation.y };
            }
        }

        HoverHandler {
            cursorShape: dragger.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        }

        Card {
            id: body
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.panelPadding
            title: "Dictation"
            iconName: "dictation"

            headerActions: [
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    role: "caption"
                    text: root.status
                },
                HeaderButton {
                    iconName: "close"
                    tooltipText: "Discard"
                    onClicked: DictationService.cancel()
                }
            ]

            // The words, framed as a field once there's text to fix.
            Rectangle {
                id: textBox

                readonly property bool editable: root.phase === "ready"

                width: parent.width
                height: Math.min(textFlick.contentHeight, metrics.height * 6) + Theme.spacingSmall * 2
                radius: Theme.borderRadius
                color: root.editing || textBox.editable && textHover.hovered ? Theme.controlFill : "transparent"
                border.width: Theme.borderWidth
                border.color: root.editing ? Theme.accent : textBox.editable ? Theme.controlBorder : "transparent"

                Behavior on color {
                    ColorAnimation { duration: Theme.animDurationFast }
                }

                HoverHandler {
                    id: textHover
                    cursorShape: textBox.editable ? Qt.IBeamCursor : Qt.ArrowCursor
                }

                Flickable {
                    id: textFlick
                    anchors.fill: parent
                    anchors.margins: Theme.spacingSmall
                    contentWidth: width
                    contentHeight: root.live ? Math.max(liveLabel.implicitHeight, metrics.height) : editor.implicitHeight
                    clip: true
                    interactive: contentHeight > height
                    boundsBehavior: Flickable.StopAtBounds
                    // Follows the words as they come.
                    onContentHeightChanged: {
                        if (root.live)
                            textFlick.contentY = Math.max(0, textFlick.contentHeight - textFlick.height);
                    }

                    Label {
                        id: liveLabel
                        visible: root.live
                        width: textFlick.width
                        wrapMode: Text.Wrap
                        textFormat: Text.StyledText
                        text: root.liveText
                    }

                    Label {
                        visible: root.live && root.liveText === ""
                        width: textFlick.width
                        wrapMode: Text.Wrap
                        color: Theme.overlay
                        text: DictationService.preparing !== ""
                            ? "Recording already; the words show once the model is in."
                            : "Speak, and the words show here."
                    }

                    TextEdit {
                        id: editor
                        visible: !root.live
                        width: textFlick.width
                        text: DictationService.text
                        textFormat: TextEdit.PlainText
                        wrapMode: TextEdit.Wrap
                        readOnly: !textBox.editable
                        selectByMouse: true
                        color: Theme.text
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.textOnAccent
                        font: metrics.font
                        onTextChanged: if (editor.activeFocus) DictationService.setText(editor.text)
                        onActiveFocusChanged: if (!editor.activeFocus) root.editing = false
                        onCursorRectangleChanged: {
                            const cursor = editor.cursorRectangle;
                            if (cursor.y < textFlick.contentY)
                                textFlick.contentY = cursor.y;
                            else if (cursor.y + cursor.height > textFlick.contentY + textFlick.height)
                                textFlick.contentY = cursor.y + cursor.height - textFlick.height;
                        }
                        Keys.onReturnPressed: event => {
                            event.accepted = true;
                            DictationService.type(true);
                        }
                        Keys.onEnterPressed: event => {
                            event.accepted = true;
                            DictationService.type(true);
                        }
                        Keys.onEscapePressed: event => {
                            event.accepted = true;
                            root.editing = false;
                            keyCatcher.forceActiveFocus();
                        }

                        // Beside the editor's own handling of the click, which places the cursor;
                        // a drag moves the card instead.
                        TapHandler {
                            enabled: textBox.editable
                            onTapped: root.edit()
                        }
                    }
                }

                // The microphone's level along the foot, while listening.
                ProgressBar {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: Theme.spacingSmall
                    anchors.bottomMargin: 0
                    height: Theme.spacingMicro
                    visible: root.phase === "listening"
                    color: "transparent"
                    value: card.shownLevel
                    fillColor: Theme.alpha(Theme.accent, Theme.tintOutline)
                }
            }

            Row {
                anchors.right: parent.right
                spacing: Theme.spacingSmall

                ActionButton {
                    visible: root.phase === "listening"
                    kind: "primary"
                    compact: true
                    iconName: "record-stop"
                    text: "Stop"
                    tooltipText: "Stop listening, then type or copy it"
                    onClicked: DictationService.stop()
                }

                ActionButton {
                    visible: root.phase !== "listening" && FeatureSupport.hasCommand("wl-copy")
                    enabled: root.phase === "ready"
                    compact: true
                    iconName: "copy"
                    text: "Copy"
                    tooltipText: "Copy it to the clipboard"
                    onClicked: DictationService.copy()
                }

                ActionButton {
                    visible: root.phase !== "listening"
                    enabled: root.phase === "ready"
                    kind: "primary"
                    compact: true
                    iconName: "keyboard"
                    text: "Type"
                    tooltipText: "Type it into the focused window"
                    onClicked: DictationService.type(false)
                }
            }
        }
    }

    PopIn {
        id: entrance
        card: card
    }

    NumberAnimation {
        id: exitAnimation
        target: card
        property: "opacity"
        to: 0
        duration: Theme.animDurationExit
        easing.type: Theme.animEasingExit
        // Also stopped, short of the end, when present() takes the card back.
        onStopped: {
            if (card.opacity <= 0)
                root.shown = false;
        }
    }

    NumberAnimation {
        id: comeBack
        target: card
        property: "opacity"
        to: 1
        duration: Theme.animDurationFast
        easing.type: Theme.animEasing
    }
}
