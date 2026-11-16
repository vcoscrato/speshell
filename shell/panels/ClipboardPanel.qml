pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Templates as T
import qs.components
import qs.services

// Clipboard history to search and copy back from, by keyboard: the search takes the
// typing, Up and Down pick an item, and Enter copies it and closes. A click copies too,
// and a hovered item can be deleted.
Card {
    id: root
    panel: "clipboard"

    property string query: ""
    // The header's trash asks before the whole history goes.
    property bool confirmingClear: false

    readonly property var history: ClipboardService.history
    readonly property var shownHistory: {
        const needle = root.query.trim().toLowerCase();
        if (needle === "")
            return root.history;
        return root.history.filter(entry => entry.preview.toLowerCase().indexOf(needle) >= 0);
    }

    function select(index) {
        clipboardRows.currentIndex = Math.max(0, Math.min(root.shownHistory.length - 1, index));
        clipboardRows.positionViewAtIndex(clipboardRows.currentIndex, ListView.Contain);
    }

    function copySelected() {
        const entry = root.shownHistory[clipboardRows.currentIndex];
        if (!entry)
            return;
        ClipboardService.copyEntry(entry);
        PanelService.dismiss();
    }

    onQueryChanged: root.select(0)
    Component.onCompleted: ClipboardService.setViewPresented(true)
    Component.onDestruction: ClipboardService.setViewPresented(false)

    headerActions: HeaderButton {
        iconName: "trash"
        visible: root.history.length > 0
        checked: root.confirmingClear
        tooltipText: "Clear clipboard history"
        onClicked: root.confirmingClear = !root.confirmingClear
    }

    // The search stays put while the history scrolls under it.
    pinnedContent: [
        Notice {
            visible: root.confirmingClear && root.history.length > 0
            iconName: "trash"
            toneColor: Theme.error
            detail: "Clear all " + root.history.length + (root.history.length === 1 ? " item?" : " items?")

            trailing: [
                ActionButton {
                    text: "Cancel"
                    compact: true
                    onClicked: root.confirmingClear = false
                },

                ActionButton {
                    text: "Clear"
                    kind: "danger"
                    compact: true
                    onClicked: {
                        root.confirmingClear = false;
                        ClipboardService.clearHistory();
                    }
                }
            ]
        },

        Field {
            visible: root.history.length > 0
            autoFocus: true
            iconName: "search"
            clearable: true
            placeholder: "Search " + root.history.length + (root.history.length === 1 ? " item" : " items")
            text: root.query
            onEdited: root.query = text
            onAccepted: root.copySelected()
            onKeyPressed: event => {
                if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) {
                    root.select(clipboardRows.currentIndex + (event.key === Qt.Key_Down ? 1 : -1));
                    event.accepted = true;
                }
            }
        },

        Label {
            role: "caption"
            width: parent.width
            text: ClipboardService.feedback.text
            color: ClipboardService.feedback.tone === "neutral" ? Theme.subtext : Theme.toneColor(ClipboardService.feedback.tone)
            elide: Text.ElideRight
            visible: text !== ""
        }
    ]

    ListView {
        id: clipboardRows

        readonly property bool scrollable: contentHeight > height + 1
        // The rows below the fold fade out at the foot.
        readonly property bool fades: clipboardRows.scrollable && !clipboardRows.atYEnd

        width: parent.width
        // About a screenful of rows, wider text scaling it with the panel.
        height: Math.min(contentHeight, Math.round(Theme.panelWidth * 1.5))
        visible: root.shownHistory.length > 0
        clip: true
        spacing: Theme.spacingTiny
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 3000
        model: root.shownHistory

        layer.enabled: clipboardRows.fades
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: fadeMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }

        T.ScrollBar.vertical: StyledScrollBar {
            policy: clipboardRows.scrollable ? T.ScrollBar.AsNeeded : T.ScrollBar.AlwaysOff
        }

        delegate: Rectangle {
            id: clipRow
            required property var modelData
            required property int index
            readonly property bool image: clipRow.modelData.kind === "image"
            readonly property bool lastCopied: clipRow.modelData.id === ClipboardService.lastCopiedId
            readonly property bool selected: clipRow.index === clipboardRows.currentIndex

            width: clipboardRows.width - (clipboardRows.scrollable ? Theme.spacingMedium : 0)
            height: clipRow.image
                ? thumbnailFrame.height + Theme.spacingSmall * 2
                : Math.max(Theme.controlHeight + Theme.spacingSmall,
                    previewText.implicitHeight + Theme.spacingSmall * 2)
            radius: Theme.borderRadius
            color: clipRow.selected
                ? Theme.cardHover
                : (clipRow.lastCopied ? Theme.selectedFill : Theme.controlFill)
            border.width: Theme.borderWidth
            border.color: clipRow.lastCopied ? Theme.selectedBorder : Theme.controlBorder

            Accessible.role: Accessible.Button
            Accessible.name: "Copy clipboard item"
            Accessible.description: clipRow.modelData.preview
            Accessible.onPressAction: ClipboardService.copyEntry(clipRow.modelData)

            // The pointer picks the row it is over, as Up and Down do.
            HoverHandler {
                id: rowHover
                onHoveredChanged: if (rowHover.hovered) clipboardRows.currentIndex = clipRow.index
            }

            Rectangle {
                id: thumbnailFrame
                visible: clipRow.image
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingSmall
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(thumbnailFrame.height * 1.75)
                height: Theme.controlHeight * 2
                radius: Theme.borderRadius
                color: Theme.crust
                clip: true

                Image {
                    id: thumbnail
                    anchors.fill: parent
                    source: clipRow.modelData.thumbnail ? "file://" + clipRow.modelData.thumbnail : ""
                    sourceSize: Qt.size(thumbnailFrame.width * 2, thumbnailFrame.height * 2)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                }

                AppIcon {
                    anchors.centerIn: parent
                    visible: thumbnail.status !== Image.Ready
                    name: "photo"
                    size: Theme.iconSizeMedium
                    iconColor: Theme.overlay
                }
            }

            Label {
                id: previewText
                anchors.left: clipRow.image ? thumbnailFrame.right : parent.left
                anchors.right: deleteButton.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: clipRow.image ? Theme.spacingMedium : Theme.spacingSmall
                anchors.rightMargin: Theme.spacingTiny
                text: clipRow.modelData.preview
                font.pixelSize: clipRow.image ? Theme.fontSizeCaption : Theme.fontSizeSmall
                color: clipRow.image || clipRow.modelData.kind === "binary"
                    ? Theme.subtext
                    : (clipRow.modelData.kind === "link" ? Theme.accent : Theme.text)
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                maximumLineCount: 2
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: ClipboardService.copyEntry(clipRow.modelData)
            }

            // Over the row's click, holding its place while hidden so the text keeps
            // its wrap.
            IconButton {
                id: deleteButton
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingTiny
                anchors.verticalCenter: parent.verticalCenter
                opacity: rowHover.hovered ? 1 : 0
                enabled: rowHover.hovered
                size: Theme.controlHeightSmall
                iconName: "trash"
                iconSize: Theme.iconSizeSmall
                iconColor: deleteButton.containsMouse ? Theme.error : Theme.subtext
                hoverColor: Theme.alpha(Theme.error, Theme.tintStrong)
                tooltipText: "Delete from history"
                onClicked: ClipboardService.remove(clipRow.modelData)
            }
        }
    }

    // Opaque but for its foot, where it fades out over a row's height.
    Rectangle {
        id: fadeMask
        width: clipboardRows.width
        height: clipboardRows.height
        visible: false
        layer.enabled: true
        gradient: Gradient {
            GradientStop { position: 0; color: "black" }
            GradientStop { position: Math.max(0, 1 - Theme.controlHeight * 1.5 / Math.max(1, fadeMask.height)); color: "black" }
            GradientStop { position: 1; color: "transparent" }
        }
    }

    EmptyState {
        visible: root.shownHistory.length === 0
        iconName: root.history.length > 0 ? "search" : "clipboard"
        title: !ClipboardService.available
            ? "Clipboard history is off"
            : (root.history.length > 0 ? "No matches" : "Nothing copied yet")
        detail: !ClipboardService.available
            ? "Install cliphist and wl-clipboard to keep a history."
            : (root.history.length > 0 ? "Nothing copied matches “" + root.query.trim() + "”."
                : "Text and images you copy show up here.")
    }
}
