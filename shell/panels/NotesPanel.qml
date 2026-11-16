pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Templates as T
import qs.components
import qs.services
import "Markdown.js" as Markdown

// Markdown notes: tabs for each note, and the open one, shown rendered and edited in place.
Card {
    id: root
    panel: "notes"

    property bool syncingFromService: false
    property bool previewMode: true
    property bool creatingNote: false
    property string renderedMarkdown: ""

    readonly property int minimumEditorLines: 8
    readonly property int maximumEditorLines: 22
    readonly property int editorPadding: Theme.spacingSmall
    readonly property int editorScrollbarInset: Theme.spacingMedium
    readonly property real editorMinimumHeight: Math.ceil(notesFontMetrics.lineSpacing * minimumEditorLines + editorPadding * 2)
    readonly property real editorMaximumHeight: Math.ceil(notesFontMetrics.lineSpacing * maximumEditorLines + editorPadding * 2)
    readonly property real editorPreferredHeight: (root.previewMode
        ? markdownText.implicitHeight
        : notesInput.implicitHeight) + editorPadding * 2

    readonly property bool canDeleteNote: NotesService.noteList.length > 1
        && NotesService.managementEnabled

    headerActions: HeaderButton {
        iconName: "copy"
        enabled: NotesService.loaded && notesInput.text !== ""
        tooltipText: "Copy notes"
        onClicked: ClipboardService.copyText(notesInput.text)
    }

    // Between paragraphs, a third of the text's height.
    function updateRenderedMarkdown() {
        root.renderedMarkdown = Markdown.render(notesInput.text, Math.round(Theme.fontSizeSmall / 3));
    }

    function exitEditMode() {
        if (!root.previewMode) {
            root.previewMode = true;
            focusSink.forceActiveFocus();
            NotesService.flush(false);
        }
    }

    function beginEditMode(clickX, clickY) {
        if (!NotesService.loaded || NotesService.mutating)
            return;
        root.previewMode = false;
        Qt.callLater(() => {
            notesInput.forceActiveFocus();
            if (typeof clickX === "number" && typeof clickY === "number") {
                const position = notesInput.positionAt(clickX, clickY);
                notesInput.cursorPosition = position >= 0
                    ? position
                    : notesInput.text.length;
            }
        });
    }

    function beginCreatingNote() {
        if (!NotesService.managementEnabled)
            return;
        root.exitEditMode();
        root.creatingNote = true;
        newNoteInput.text = "";
        newNoteInput.focusInput();
    }

    function syncFromService() {
        if (notesInput.text === NotesService.text)
            return;

        root.syncingFromService = true;
        notesInput.text = NotesService.text;
        root.syncingFromService = false;
        if (root.previewMode)
            root.updateRenderedMarkdown();
    }

    onPreviewModeChanged: {
        if (root.previewMode)
            root.updateRenderedMarkdown();
    }

    Component.onCompleted: {
        NotesService.read();
        root.syncFromService();
    }
    Component.onDestruction: NotesService.flush(true)

    Item {
        id: focusSink
        focus: true
    }

    Connections {
        target: NotesService
        function onTextChanged() {
            root.syncFromService();
        }
    }

    Connections {
        target: root.Window ? root.Window.window : null
        function onActiveFocusItemChanged() {
            if (!root.previewMode && root.Window && root.Window.window
                    && root.Window.window.activeFocusItem !== notesInput) {
                root.exitEditMode();
            }
        }
    }

    Label {
        width: parent.width
        visible: NotesService.errorText !== ""
        text: NotesService.errorText
        color: Theme.error
    }

    FontMetrics {
        id: notesFontMetrics
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
    }

    Flickable {
        width: parent.width
        height: Theme.controlHeightSmall
        contentWidth: tabsRow.width
        contentHeight: height
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Row {
            id: tabsRow
            spacing: Theme.spacingTiny
            height: parent.height

            Repeater {
                model: NotesService.noteList
                delegate: Tab {
                    id: tabItem
                    required property string modelData
                    text: tabItem.modelData
                    current: NotesService.currentNote === tabItem.modelData
                    trailingSpace: root.canDeleteNote ? deleteButton.size - Theme.spacingTiny : 0
                    enabled: NotesService.managementEnabled
                    onClicked: {
                        root.exitEditMode();
                        NotesService.selectNote(tabItem.modelData);
                    }

                    IconButton {
                        id: deleteButton
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingMicro
                        anchors.verticalCenter: parent.verticalCenter
                        size: Theme.controlHeightSmall - Theme.spacingTiny * 2
                        iconName: "trash"
                        iconSize: Theme.iconSizeTiny
                        iconColor: deleteButton.containsMouse ? Theme.error : Theme.subtext
                        enabled: root.canDeleteNote
                        visible: root.canDeleteNote && (tabItem.hovered || deleteButton.containsMouse)
                        tooltipText: "Delete " + tabItem.modelData
                        onClicked: {
                            root.exitEditMode();
                            NotesService.deleteNote(tabItem.modelData);
                        }
                    }
                }
            }

            // A tab-sized button that becomes the new note's name field.
            Item {
                id: newTabButton
                height: Theme.controlHeightSmall
                width: root.creatingNote ? Theme.fontSizeSmall * 10 : Theme.controlHeightSmall
                enabled: NotesService.managementEnabled
                opacity: newTabButton.enabled ? 1.0 : Theme.disabledOpacity

                Behavior on width {
                    NumberAnimation { duration: Theme.animDuration; easing.type: Theme.animEasing }
                }

                IconButton {
                    anchors.fill: parent
                    visible: !root.creatingNote
                    iconName: "plus"
                    iconSize: Theme.iconSizeSmall
                    iconColor: Theme.subtext
                    color: containsMouse ? Theme.cardHover : Theme.controlFill
                    tooltipText: "Create note"
                    onClicked: root.beginCreatingNote()
                }

                Field {
                    id: newNoteInput
                    anchors.fill: parent
                    visible: root.creatingNote
                    compact: true
                    placeholder: "Note name"
                    maximumLength: 60

                    function create() {
                        if (newNoteInput.text.trim() !== "")
                            NotesService.createNote(newNoteInput.text.trim());
                        root.creatingNote = false;
                    }

                    onAccepted: newNoteInput.create()
                    onCancelled: {
                        root.creatingNote = false;
                        focusSink.forceActiveFocus();
                    }
                    // Clicking away names it too.
                    onInputFocusedChanged: {
                        if (!newNoteInput.inputFocused && root.creatingNote
                                && root.Window && root.Window.window && root.Window.window.visible)
                            newNoteInput.create();
                    }
                }
            }
        }
    }

    Notice {
        id: deleteUndoBar

        readonly property string pendingName: NotesService.pendingDeleteNote

        visible: pendingName !== ""
        iconName: "trash"
        detail: pendingName + " deleted"
        progress: 0

        onPendingNameChanged: {
            if (pendingName !== "") {
                progress = 1;
                deleteCountdown.restart();
            } else {
                deleteCountdown.stop();
                progress = 0;
            }
        }

        trailing: ActionButton {
            text: "Undo"
            compact: true
            iconName: "back"
            enabled: !NotesService.mutating
            onClicked: {
                deleteCountdown.stop();
                NotesService.undoDelete();
            }
        }
    }

    NumberAnimation {
        id: deleteCountdown
        target: deleteUndoBar
        property: "progress"
        from: 1
        to: 0
        duration: NotesService.undoMs
    }

    Rectangle {
        width: parent.width
        height: Math.min(root.editorMaximumHeight, Math.max(root.editorMinimumHeight, root.editorPreferredHeight))
        radius: Theme.borderRadius
        color: Theme.controlFill
        border.width: Theme.borderWidth
        border.color: (!root.previewMode && notesInput.activeFocus)
            ? Theme.accent
            : Theme.controlBorder

        Flickable {
            id: notesFlickable
            anchors.fill: parent
            anchors.margins: root.editorPadding
            readonly property bool needsVerticalScroll: contentHeight > height + 1
            // Always reserve the scrollbar gutter: making the text width depend on
            // needsVerticalScroll creates a binding loop through the wrapped height.
            contentWidth: Math.max(0, width - root.editorScrollbarInset)
            contentHeight: Math.max(
                root.previewMode ? markdownText.implicitHeight : notesInput.implicitHeight,
                height
            )
            boundsBehavior: Flickable.StopAtBounds
            interactive: needsVerticalScroll
            clip: true

            T.ScrollBar.vertical: StyledScrollBar {
                policy: notesFlickable.needsVerticalScroll ? T.ScrollBar.AsNeeded : T.ScrollBar.AlwaysOff
            }

            T.TextArea {
                id: notesInput
                focusPolicy: Qt.ClickFocus
                visible: !root.previewMode
                width: notesFlickable.contentWidth
                height: notesFlickable.contentHeight
                implicitWidth: contentWidth
                implicitHeight: contentHeight
                wrapMode: TextEdit.Wrap
                padding: 0
                color: Theme.text
                selectionColor: Theme.accent
                selectedTextColor: Theme.onAccent
                font.pixelSize: Theme.fontSizeSmall
                font.family: Theme.fontFamily
                enabled: NotesService.loaded && !NotesService.mutating

                onTextChanged: {
                    if (!root.syncingFromService)
                        NotesService.setText(text);
                }

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) {
                        root.exitEditMode();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (event.modifiers & Qt.ShiftModifier) {
                            const position = notesInput.cursorPosition;
                            notesInput.insert(position, "\n");
                            notesInput.cursorPosition = position + 1;
                        } else {
                            root.exitEditMode();
                        }
                        event.accepted = true;
                    }
                }

                Label {
                    width: parent.width
                    visible: notesInput.text === "" && !notesInput.preeditText
                    text: "Keep notes, prompts, commands, or text you want nearby.\nEnter to finish · Shift+Enter for a new line"
                    color: Theme.subtext
                    wrapMode: Text.WordWrap
                }

                onActiveFocusChanged: {
                    if (!activeFocus && root.Window && root.Window.window && root.Window.window.visible) {
                        root.exitEditMode();
                    }
                }
            }

            Item {
                visible: root.previewMode
                width: notesFlickable.contentWidth
                height: Math.max(markdownText.implicitHeight, notesFlickable.height)

                // A TextEdit, not a Text: under Qt 6.12, scrolling a Text over 10,000
                // characters that holds a Markdown table segfaults the scene graph
                // renderer in QSGBatchRenderer::prepareAlphaBatches.
                TextEdit {
                    id: markdownText
                    width: parent.width
                    text: root.renderedMarkdown
                    textFormat: TextEdit.MarkdownText
                    wrapMode: TextEdit.Wrap
                    readOnly: true
                    activeFocusOnPress: false
                    color: Theme.text
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: Theme.fontFamily
                }

                // Worded as the editor's placeholder.
                Label {
                    width: parent.width
                    visible: root.renderedMarkdown === ""
                    text: "Keep notes, prompts, commands, or text you want nearby.\nClick to start writing."
                    color: Theme.subtext
                    wrapMode: Text.WordWrap
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: markdownText.linkAt(mouseX, mouseY) !== ""
                        ? Qt.PointingHandCursor
                        : Qt.IBeamCursor
                    onClicked: (mouse) => {
                        const link = markdownText.linkAt(mouse.x, mouse.y);
                        if (link !== "") {
                            Qt.openUrlExternally(link);
                            return;
                        }
                        root.beginEditMode(mouse.x, mouse.y);
                    }
                }
            }
        }
    }
}
