pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.components
import qs.services
import qs.theme

Card {
    id: root
    title: "Notes"
    iconName: "notes"

    property bool presented: false
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
        && NotesService.pendingDeleteNote === ""
        && NotesService.managementEnabled

    Item {
        id: focusSink
        focus: true
    }

    // Qt leaves almost no room between Markdown paragraphs. Put a short spacer
    // paragraph between two plain ones; lists, quotes, headings, tables, and code
    // keep their own structure.
    function spaceParagraphs(src) {
        const structural = /^\s*([-*+]\s|\d+[.)]\s|#|>|\||```|~~~)|^\s{4}/;
        const lines = src.split("\n");
        const out = [];
        let inFence = false;
        let previous = "";
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            if (/^\s*(```|~~~)/.test(line))
                inFence = !inFence;
            if (inFence || line.trim() !== "") {
                out.push(line);
                previous = line;
                continue;
            }
            let next = i + 1;
            while (next < lines.length && lines[next].trim() === "")
                next++;
            const between = previous.trim() !== "" && next < lines.length
                && !structural.test(previous) && !structural.test(lines[next]);
            out.push(between ? "\n<span style='font-size:4px'>&nbsp;</span>\n" : "");
            i = next - 1;
            previous = "";
        }
        return out.join("\n");
    }

    function updateRenderedMarkdown() {
        var src = notesInput.text;
        if (!src || src.trim() === "") {
            root.renderedMarkdown = "";
            return;
        }
        var str = root.spaceParagraphs(String(src));

        // Subscripts: $X_1$ or $X_{12}$
        str = str.replace(/\$([a-zA-Z0-9]+)_\{?([a-zA-Z0-9+\-=]+)\}?\$/g, "$1<sub>$2</sub>");
        // Superscripts: $X^2$ or $X^{12}$
        str = str.replace(/\$([a-zA-Z0-9]+)\^\{?([a-zA-Z0-9+\-=]+)\}?\$/g, "$1<sup>$2</sup>");
        // Simple standalone X_1 or X^2 outside formulas
        str = str.replace(/\b([a-zA-Z])_([0-9a-zA-Z])\b/g, "$1<sub>$2</sub>");
        str = str.replace(/\b([a-zA-Z])\^([0-9a-zA-Z])\b/g, "$1<sup>$2</sup>");

        // TeX / Math symbols
        str = str.replace(/\\alpha\b/g, "α")
                 .replace(/\\beta\b/g, "β")
                 .replace(/\\gamma\b/g, "γ")
                 .replace(/\\delta\b/g, "δ")
                 .replace(/\\pi\b/g, "π")
                 .replace(/\\theta\b/g, "θ")
                 .replace(/\\lambda\b/g, "λ")
                 .replace(/\\sigma\b/g, "σ")
                 .replace(/\\sum\b/g, "∑")
                 .replace(/\\int\b/g, "∫")
                 .replace(/\\infty\b/g, "∞")
                 .replace(/\\approx\b/g, "≈")
                 .replace(/\\neq\b/g, "≠")
                 .replace(/\\le\b/g, "≤")
                 .replace(/\\ge\b/g, "≥")
                 .replace(/\\times\b/g, "×")
                 .replace(/\\div\b/g, "÷")
                 .replace(/\\pm\b/g, "±")
                 .replace(/\\sqrt\{([^}]+)\}/g, "√($1)");

        root.renderedMarkdown = str;
    }

    function exitEditMode() {
        if (!root.previewMode) {
            root.previewMode = true;
            focusSink.forceActiveFocus();
            NotesService.flush(false);
        }
    }

    function beginEditMode(clickX, clickY) {
        if (!NotesService.managementEnabled)
            return;
        root.previewMode = false;
        Qt.callLater(function() {
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
        newNoteInput.forceActiveFocus();
    }

    onPreviewModeChanged: {
        if (root.previewMode)
            root.updateRenderedMarkdown();
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

    function restoreEditingFocus() {
        if (!root.presented)
            return;
        if (root.creatingNote)
            newNoteInput.forceActiveFocus();
        else if (!root.previewMode)
            notesInput.forceActiveFocus();
    }

    onPresentedChanged: {
        if (root.presented) {
            NotesService.read();
            Qt.callLater(root.restoreEditingFocus);
        }
    }

    Component.onCompleted: {
        NotesService.read();
        root.syncFromService();
    }
    Component.onDestruction: NotesService.flush(true)

    Connections {
        target: NotesService
        function onTextChanged() {
            root.syncFromService();
        }
    }

    Connections {
        target: root.Window ? root.Window.window : null
        function onActiveFocusItemChanged() {
            if (root.presented && !root.previewMode && root.Window && root.Window.window
                    && root.Window.window.activeFocusItem !== notesInput) {
                root.exitEditMode();
            }
        }
    }

    headerActions: IconButton {
        size: Theme.controlHeightSmall
        iconName: "copy"
        iconSize: Theme.iconSizeSmall
        iconColor: enabled ? Theme.subtextBright : Theme.overlay
        enabled: NotesService.loaded && notesInput.text !== ""
        tooltipText: "Copy notes"
        onClicked: ClipboardService.copyText(notesInput.text)
    }

    Text {
        width: parent.width
        visible: NotesService.errorText !== ""
        text: NotesService.errorText
        color: Theme.error
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
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
            spacing: Theme.spacingSmall
            height: parent.height

            Repeater {
                model: NotesService.noteList
                delegate: Rectangle {
                    id: tabItem
                    required property string modelData
                    readonly property bool isSelected: NotesService.currentNote === tabItem.modelData
                    height: Theme.controlHeightSmall
                    width: tabText.implicitWidth + (root.canDeleteNote ? 28 : Theme.spacingLarge)
                    radius: Theme.borderRadiusSmall
                    enabled: NotesService.managementEnabled
                    opacity: tabItem.enabled ? 1.0 : Theme.disabledOpacity
                    color: tabItem.isSelected
                        ? Theme.alpha(Theme.accent, Theme.tintStrong)
                        : (tabHover.hovered ? Theme.cardHover : Theme.controlFill)
                    border.width: Theme.borderWidth
                    border.color: tabItem.isSelected
                        ? Theme.selectedBorder
                        : "transparent"

                    Accessible.role: Accessible.PageTab
                    Accessible.name: tabItem.modelData
                    Accessible.description: tabItem.isSelected ? "Current note" : "Switch note"
                    Accessible.onPressAction: tabItem.activate()

                    function activate() {
                        if (!tabItem.enabled)
                            return;
                        root.exitEditMode();
                        NotesService.selectNote(tabItem.modelData);
                    }

                    HoverHandler {
                        id: tabHover
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: tabItem.activate()
                    }

                    Text {
                        id: tabText
                        text: tabItem.modelData
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingSmall
                        anchors.verticalCenter: parent.verticalCenter
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: tabItem.isSelected ? Theme.text : Theme.subtext
                    }

                    IconButton {
                        id: deleteButton
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingMicro
                        anchors.verticalCenter: parent.verticalCenter
                        size: 18
                        iconName: "trash"
                        iconSize: Theme.iconSizeTiny
                        iconColor: deleteButton.containsMouse
                            ? Theme.error
                            : Theme.subtext
                        enabled: root.canDeleteNote
                        visible: root.canDeleteNote && tabHover.hovered
                        tooltipText: "Delete " + tabItem.modelData
                        onClicked: {
                            root.exitEditMode();
                            NotesService.deleteNote(tabItem.modelData);
                        }
                    }
                }
            }

            Rectangle {
                id: newTabButton
                height: Theme.controlHeightSmall
                width: root.creatingNote ? 110 : Theme.controlHeightSmall
                radius: Theme.borderRadiusSmall
                color: root.creatingNote
                    ? Theme.card
                    : (newTabHover.hovered ? Theme.cardHover : Theme.controlFill)
                border.width: Theme.borderWidth
                border.color: root.creatingNote
                    ? Theme.accent
                    : "transparent"
                enabled: NotesService.managementEnabled
                opacity: newTabButton.enabled ? 1.0 : Theme.disabledOpacity

                Accessible.role: Accessible.Button
                Accessible.name: "Create note"
                Accessible.onPressAction: root.beginCreatingNote()

                Behavior on width {
                    NumberAnimation { duration: Theme.animDuration; easing.type: Theme.animEasing }
                }

                HoverHandler {
                    id: newTabHover
                    enabled: !root.creatingNote
                }

                MouseArea {
                    anchors.fill: parent
                    visible: !root.creatingNote
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.beginCreatingNote()
                }

                AppIcon {
                    name: "plus"
                    size: Theme.iconSizeSmall
                    iconColor: Theme.subtext
                    anchors.centerIn: parent
                    visible: !root.creatingNote
                }

                TextInput {
                    id: newNoteInput
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingSmall
                    anchors.rightMargin: Theme.spacingSmall
                    verticalAlignment: TextInput.AlignVCenter
                    visible: root.creatingNote
                    color: Theme.text
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.onAccent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    clip: true
                    maximumLength: 60
                    Accessible.name: "Note name"

                    onAccepted: {
                        if (text.trim() !== "")
                            NotesService.createNote(text.trim());
                        root.creatingNote = false;
                    }

                    onActiveFocusChanged: {
                        if (!activeFocus && root.creatingNote && root.presented
                                && root.Window && root.Window.window && root.Window.window.visible) {
                            if (text.trim() !== "")
                                NotesService.createNote(text.trim());
                            root.creatingNote = false;
                        }
                    }

                    Keys.onEscapePressed: {
                        root.creatingNote = false;
                        focusSink.forceActiveFocus();
                    }
                }
            }
        }
    }

    Rectangle {
        id: deleteUndoBar

        readonly property string pendingName: NotesService.pendingDeleteNote
        property real progress: 0

        visible: pendingName !== ""
        width: parent.width
        height: visible ? Theme.controlHeight : 0
        radius: Theme.borderRadiusSmall
        color: Theme.alpha(Theme.warning, Theme.tintSubtle)
        border.width: Theme.borderWidth
        border.color: Theme.alpha(Theme.warning, Theme.tintOutline)
        clip: true

        Accessible.role: Accessible.AlertMessage
        Accessible.name: pendingName !== "" ? pendingName + " deleted. Undo available." : ""

        onPendingNameChanged: {
            if (pendingName !== "") {
                progress = 1;
                deleteCountdown.restart();
            } else {
                deleteCountdown.stop();
                progress = 0;
            }
        }

        Row {
            anchors.fill: parent
            anchors.leftMargin: Theme.spacingSmall
            anchors.rightMargin: Theme.spacingTiny
            spacing: Theme.spacingSmall

            AppIcon {
                name: "trash"
                size: Theme.iconSizeSmall
                iconColor: Theme.warning
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                width: Math.max(0, deleteUndoBar.width
                    - undoDeleteButton.width
                    - Theme.spacingSmall * 4
                    - Theme.iconSizeSmall)
                text: deleteUndoBar.pendingName + " deleted"
                elide: Text.ElideRight
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                anchors.verticalCenter: parent.verticalCenter
            }

            ActionButton {
                id: undoDeleteButton
                text: "Undo"
                iconName: "back"
                compact: true
                anchors.verticalCenter: parent.verticalCenter
                enabled: !NotesService.mutating
                onClicked: {
                    deleteCountdown.stop();
                    NotesService.undoDelete();
                }
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            width: parent.width * deleteUndoBar.progress
            height: Theme.separatorThickness
            color: Theme.warning
        }

        NumberAnimation {
            id: deleteCountdown
            target: deleteUndoBar
            property: "progress"
            from: 1
            to: 0
            duration: 5000
        }
    }

    Rectangle {
        width: parent.width
        height: Math.min(root.editorMaximumHeight, Math.max(root.editorMinimumHeight, root.editorPreferredHeight))
        radius: Theme.borderRadiusSmall
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

            ScrollBar.vertical: StyledScrollBar {
                policy: notesFlickable.needsVerticalScroll ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            }

            TextArea {
                id: notesInput
                focusPolicy: Qt.ClickFocus
                visible: !root.previewMode
                width: notesFlickable.contentWidth
                height: notesFlickable.contentHeight
                wrapMode: TextEdit.Wrap
                background: null
                topPadding: 0
                bottomPadding: 0
                leftPadding: 0
                rightPadding: 0
                placeholderText: "Keep notes, prompts, commands, or text you want nearby.\nEnter to finish · Shift+Enter for a new line"
                color: Theme.text
                selectionColor: Theme.accent
                selectedTextColor: Theme.onAccent
                placeholderTextColor: Theme.subtext
                font.pixelSize: Theme.fontSizeSmall
                font.family: Theme.fontFamily
                enabled: NotesService.managementEnabled

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

                onActiveFocusChanged: {
                    if (!activeFocus && root.presented
                            && root.Window && root.Window.window && root.Window.window.visible) {
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
                    text: root.renderedMarkdown !== "" ? root.renderedMarkdown : "*No note content. Click anywhere in box to add notes.*"
                    textFormat: TextEdit.MarkdownText
                    wrapMode: TextEdit.Wrap
                    readOnly: true
                    activeFocusOnPress: false
                    color: Theme.text
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: Theme.fontFamily
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: markdownText.linkAt(mouseX, mouseY) !== ""
                        ? Qt.PointingHandCursor
                        : Qt.IBeamCursor
                    onClicked: (mouse) => {
                        var link = markdownText.linkAt(mouse.x, mouse.y);
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
