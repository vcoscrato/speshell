pragma ComponentBehavior: Bound
import QtQuick
import qs.components
import qs.services
import qs.theme

Card {
    id: root
    title: "Clipboard"
    iconName: "clipboard"

    property bool presented: false
    property string query: ""

    readonly property var history: ClipboardService.history
    readonly property var shownHistory: {
        var needle = root.query.trim().toLowerCase();
        if (needle === "")
            return root.history;
        return root.history.filter(function(entry) {
            return entry.preview.toLowerCase().indexOf(needle) >= 0;
        });
    }

    onPresentedChanged: {
        ClipboardService.setViewPresented(root.presented);
        if (!root.presented)
            root.query = "";
    }
    Component.onCompleted: ClipboardService.setViewPresented(root.presented)
    Component.onDestruction: ClipboardService.setViewPresented(false)

    headerActions: IconButton {
        iconName: "trash"
        iconSize: Theme.iconSizeSmall
        size: Theme.controlHeightSmall
        iconColor: Theme.subtextBright
        visible: root.history.length > 0
        tooltipText: "Clear clipboard history"
        onClicked: ClipboardService.clearHistory()
    }

    Column {
        width: parent.width
        spacing: Theme.spacingSmall

        Rectangle {
            width: parent.width
            height: Theme.controlHeight
            visible: root.history.length > 0
            radius: Theme.borderRadiusSmall
            color: Theme.controlFill
            border.width: Theme.borderWidth
            border.color: searchInput.activeFocus ? Theme.selectedBorder : Theme.controlBorder

            AppIcon {
                id: searchIcon
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingSmall
                anchors.verticalCenter: parent.verticalCenter
                name: "search"
                size: Theme.iconSizeSmall
                iconColor: searchInput.activeFocus ? Theme.accent : Theme.subtext
            }

            TextInput {
                id: searchInput
                anchors.left: searchIcon.right
                anchors.leftMargin: Theme.spacingSmall
                anchors.right: clearSearch.visible ? clearSearch.left : parent.right
                anchors.rightMargin: Theme.spacingSmall
                anchors.verticalCenter: parent.verticalCenter
                text: root.query
                color: Theme.text
                selectionColor: Theme.accent
                selectedTextColor: Theme.onAccent
                font.pixelSize: Theme.fontSizeSmall
                font.family: Theme.fontFamily
                clip: true
                onTextEdited: root.query = text
                Keys.onEscapePressed: function(event) {
                    if (root.query === "") {
                        event.accepted = false;
                        return;
                    }
                    root.query = "";
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Search " + root.history.length + (root.history.length === 1 ? " item" : " items")
                    color: Theme.overlay
                    font: searchInput.font
                    visible: searchInput.text === "" && !searchInput.preeditText
                }
            }

            IconButton {
                id: clearSearch
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingTiny
                anchors.verticalCenter: parent.verticalCenter
                visible: root.query !== ""
                iconName: "close"
                iconSize: Theme.iconSizeTiny
                size: Theme.controlHeightSmall
                iconColor: Theme.subtext
                tooltipText: "Clear search"
                onClicked: root.query = ""
            }
        }

        Text {
            width: parent.width
            text: ClipboardService.feedbackText
            font.pixelSize: Theme.fontSizeCaption
            font.family: Theme.fontFamily
            color: {
                if (ClipboardService.feedbackTone === "success") return Theme.success;
                if (ClipboardService.feedbackTone === "warning") return Theme.warning;
                if (ClipboardService.feedbackTone === "error") return Theme.error;
                return Theme.subtext;
            }
            elide: Text.ElideRight
            visible: text !== ""
        }

        Column {
            id: clipboardRows
            width: parent.width
            spacing: Theme.spacingTiny

            Repeater {
                model: root.shownHistory

                delegate: Rectangle {
                    id: clipRow
                    required property var modelData
                    readonly property bool image: clipRow.modelData.kind === "image"
                    readonly property bool lastCopied: clipRow.modelData.id === ClipboardService.lastCopiedId

                    width: clipboardRows.width
                    height: clipRow.image
                        ? thumbnailFrame.height + Theme.spacingSmall * 2
                        : Math.max(Theme.controlHeight + Theme.spacingSmall,
                            previewText.implicitHeight + Theme.spacingSmall * 2)
                    radius: Theme.borderRadiusSmall
                    color: clipMouse.containsMouse
                        ? Theme.cardHover
                        : (clipRow.lastCopied ? Theme.selectedFill : Theme.controlFill)
                    border.width: Theme.borderWidth
                    border.color: clipRow.lastCopied ? Theme.selectedBorder : Theme.controlBorder

                    Accessible.role: Accessible.Button
                    Accessible.name: "Copy clipboard item"
                    Accessible.description: clipRow.modelData.preview
                    Accessible.onPressAction: ClipboardService.copyEntry(clipRow.modelData)

                    Rectangle {
                        id: thumbnailFrame
                        visible: clipRow.image
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingSmall
                        anchors.verticalCenter: parent.verticalCenter
                        width: 112
                        height: 64
                        radius: Theme.borderRadiusSmall
                        color: Theme.crust
                        clip: true

                        Image {
                            id: thumbnail
                            anchors.fill: parent
                            source: clipRow.modelData.thumbnail ? "file://" + clipRow.modelData.thumbnail : ""
                            sourceSize: Qt.size(224, 128)
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

                    Text {
                        id: previewText
                        anchors.left: clipRow.image ? thumbnailFrame.right : parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: clipRow.image ? Theme.spacingMedium : Theme.spacingSmall
                        anchors.rightMargin: Theme.spacingSmall
                        text: clipRow.modelData.preview
                        font.pixelSize: clipRow.image ? Theme.fontSizeCaption : Theme.fontSizeSmall
                        font.family: Theme.fontFamily
                        color: clipRow.image || clipRow.modelData.kind === "binary"
                            ? Theme.subtext
                            : (clipRow.modelData.kind === "link" ? Theme.accent : Theme.text)
                        wrapMode: Text.Wrap
                        elide: Text.ElideRight
                        maximumLineCount: 2
                    }

                    MouseArea {
                        id: clipMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ClipboardService.copyEntry(clipRow.modelData)
                    }
                }
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
}
